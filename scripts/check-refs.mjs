#!/usr/bin/env node
/**
 * Static reference checker for the ArkTS application.
 *
 * Why this exists: the SDK is the only real compiler, and on a hackathon clock a
 * missing resource or a mistyped import costs a full build cycle to discover.
 * This script checks the two failure classes that are decidable without a
 * compiler:
 *
 *   1. every relative import resolves to a file that exists
 *   2. every $string: / $media: / $color: / $profile: reference resolves to a
 *      declared resource, and every page in main_pages.json exists
 *
 * It is not a substitute for `devecocli build`. It catches typos and leftovers.
 *
 * Usage: node scripts/check-refs.mjs
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const appRoot = path.join(repoRoot, 'app');
const moduleRoot = path.join(appRoot, 'entry');
const etsRoot = path.join(moduleRoot, 'src/main/ets');
const resBase = path.join(moduleRoot, 'src/main/resources/base');

let failures = 0;
let checks = 0;

function ok(message) {
  checks++;
  console.log(`  ok    ${message}`);
}

function fail(message) {
  checks++;
  failures++;
  console.log(`  FAIL  ${message}`);
}

function walkFiles(dir, predicate, out = []) {
  if (!fs.existsSync(dir)) {
    return out;
  }
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walkFiles(full, predicate, out);
    } else if (predicate(full)) {
      out.push(full);
    }
  }
  return out;
}

/** Read a JSON5-ish resource file. These files are plain JSON in practice. */
function readResourceJson(file) {
  if (!fs.existsSync(file)) {
    return null;
  }
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    fail(`${path.relative(repoRoot, file)} is not valid JSON: ${error.message}`);
    return null;
  }
}

function resourceNames(file, key) {
  const data = readResourceJson(file);
  if (data === null || !Array.isArray(data[key])) {
    return [];
  }
  return data[key].map((item) => item.name);
}

// ---------------------------------------------------------------------------
// 1. Relative imports resolve
// ---------------------------------------------------------------------------
console.log('Relative imports');

const sourceFiles = walkFiles(
  etsRoot,
  (file) => file.endsWith('.ets') || file.endsWith('.ts'),
);

const importPattern = /(?:from|import)\s*\(?\s*['"](\.[^'"]+)['"]/g;

for (const file of sourceFiles) {
  const text = fs.readFileSync(file, 'utf8');
  const dir = path.dirname(file);
  let match = importPattern.exec(text);
  while (match !== null) {
    const specifier = match[1];
    const target = path.resolve(dir, specifier);
    const candidates = [
      target,
      `${target}.ets`,
      `${target}.ts`,
      path.join(target, 'index.ets'),
      path.join(target, 'index.ts'),
    ];
    const found = candidates.some((candidate) =>
      fs.existsSync(candidate) && fs.statSync(candidate).isFile());
    if (!found) {
      fail(`${path.relative(repoRoot, file)} imports '${specifier}', which does not resolve`);
    }
    match = importPattern.exec(text);
  }
}
if (failures === 0) {
  ok(`${sourceFiles.length} source files, every relative import resolves`);
}

// ---------------------------------------------------------------------------
// 2. Resource references resolve
// ---------------------------------------------------------------------------
console.log('Resource references');

const stringNames = resourceNames(path.join(resBase, 'element/string.json'), 'string');
const colorNames = resourceNames(path.join(resBase, 'element/color.json'), 'color');
const mediaDir = path.join(resBase, 'media');
const profileDir = path.join(resBase, 'profile');
const mediaFiles = fs.existsSync(mediaDir) ? fs.readdirSync(mediaDir) : [];
const profileFiles = fs.existsSync(profileDir) ? fs.readdirSync(profileDir) : [];

const resourcePattern = /\$(string|media|color|profile):([A-Za-z0-9_]+)/g;
const filesToScan = [
  path.join(moduleRoot, 'src/main/module.json5'),
  ...sourceFiles,
  ...profileFiles.map((name) => path.join(profileDir, name)),
];

const seen = new Set();
for (const file of filesToScan) {
  if (!fs.existsSync(file)) {
    continue;
  }
  const text = fs.readFileSync(file, 'utf8');
  let match = resourcePattern.exec(text);
  while (match !== null) {
    const kind = match[1];
    const name = match[2];
    const key = `${kind}:${name}`;
    if (seen.has(key)) {
      match = resourcePattern.exec(text);
      continue;
    }
    seen.add(key);

    if (kind === 'string' && !stringNames.includes(name)) {
      fail(`$string:${name} is referenced but not declared in element/string.json`);
    } else if (kind === 'color' && !colorNames.includes(name)) {
      fail(`$color:${name} is referenced but not declared in element/color.json`);
    } else if (kind === 'media'
      && !mediaFiles.some((f) => f === name || f.startsWith(`${name}.`))) {
      fail(`$media:${name} is referenced but no matching file exists in media/`);
    } else if (kind === 'profile' && !profileFiles.includes(`${name}.json`)) {
      fail(`$profile:${name} is referenced but profile/${name}.json does not exist`);
    }
    match = resourcePattern.exec(text);
  }
}
if (failures === 0) {
  ok(`${seen.size} distinct resource references resolve`);
}

// ---------------------------------------------------------------------------
// 3. Pages declared in main_pages.json exist
// ---------------------------------------------------------------------------
console.log('Declared pages');

const mainPages = readResourceJson(path.join(profileDir, 'main_pages.json'));
if (mainPages === null || !Array.isArray(mainPages.src)) {
  fail('profile/main_pages.json is missing or has no "src" array');
} else {
  for (const page of mainPages.src) {
    const file = path.join(etsRoot, `${page}.ets`);
    if (fs.existsSync(file)) {
      ok(`page '${page}' exists`);
    } else {
      fail(`page '${page}' is declared but ${path.relative(repoRoot, file)} does not exist`);
    }
  }
}

// ---------------------------------------------------------------------------
// 4. Extension ability entry points exist (module.json5 srcEntry)
// ---------------------------------------------------------------------------
console.log('Declared entry points');

const moduleJsonPath = path.join(moduleRoot, 'src/main/module.json5');
if (fs.existsSync(moduleJsonPath)) {
  const text = fs.readFileSync(moduleJsonPath, 'utf8');
  const srcEntryPattern = /"srcEntry"\s*:\s*"([^"]+)"/g;
  let match = srcEntryPattern.exec(text);
  while (match !== null) {
    const relative = match[1].replace(/^\.\//, '');
    const file = path.join(moduleRoot, 'src/main', relative);
    if (fs.existsSync(file)) {
      ok(`srcEntry '${match[1]}' exists`);
    } else {
      fail(`srcEntry '${match[1]}' is declared but does not exist`);
    }
    match = srcEntryPattern.exec(text);
  }
}

// ---------------------------------------------------------------------------
// 5. The generated core copy matches its canonical source
//
// core/src is the single source of truth and app/entry/src/main/ets/core is
// generated from it by scripts/sync-core.sh. That invariant is easy to break and
// impossible to notice: both versions compile, and the tests run against core/src
// rather than the copy, so a stale copy passes every other check.
//
// This was not hypothetical. Prelint found it in review: the canonical source had
// `forceOffline?: boolean` while the copy still had the required `forceOffline:
// boolean`, because sync-core.sh had been run before the field was made optional
// and not afterwards. Hence this check.
// ---------------------------------------------------------------------------
console.log('Generated core copy');

const canonicalDir = path.join(repoRoot, 'core/src');
const generatedDir = path.join(appRoot, 'entry/src/main/ets/core');

/** The same transform scripts/sync-core.sh applies when copying. */
function transformForArkTs(text) {
  return text.replace(
    /(from\s+["'])(\.\.?\/[^"']+?)\.ts(["'])/g,
    '$1$2$3',
  );
}

if (!fs.existsSync(canonicalDir)) {
  fail('core/src does not exist, so the generated copy cannot be checked');
} else {
  const canonicalFiles = walkFiles(canonicalDir, (file) => file.endsWith('.ts'));
  for (const source of canonicalFiles) {
    const relative = path.relative(canonicalDir, source);
    const generated = path.join(generatedDir, relative);
    if (!fs.existsSync(generated)) {
      fail(`${relative} exists in core/src but is missing from the generated copy`);
      continue;
    }
    const expected = transformForArkTs(fs.readFileSync(source, 'utf8'));
    const actual = fs.readFileSync(generated, 'utf8');
    if (expected !== actual) {
      fail(`${relative} has drifted from core/src; run scripts/sync-core.sh`);
    }
  }
  if (failures === 0) {
    ok(`${canonicalFiles.length} generated files match core/src exactly`);
  }
}

console.log('');
if (failures > 0) {
  console.log(`${failures} of ${checks} checks FAILED`);
  process.exit(1);
}
console.log(`all ${checks} checks passed`);
