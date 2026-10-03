/**
 * Parser tests. The parser is the trust boundary for model output, so every
 * rejection path is exercised explicitly.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  DEFAULT_LIMITS,
  extractObject,
  parseVariants,
  stripFences,
} from '../src/parse.ts';
import { VariantParseError } from '../src/contracts.ts';

const THREE = '{"variants":[{"label":"A","text":"Ala ma kota."},' +
  '{"label":"B","text":"Ala posiada kota."},{"label":"C","text":"Kot jest Ali."}]}';

test('parses a clean response', () => {
  const variants = parseVariants(THREE, DEFAULT_LIMITS, 'ala ma kota', []);
  assert.equal(variants.length, 3);
  assert.equal(variants[0].label, 'A');
  assert.equal(variants[0].text, 'Ala ma kota.');
});

test('strips a markdown code fence', () => {
  const raw = '```json\n' + THREE + '\n```';
  const variants = parseVariants(raw, DEFAULT_LIMITS, 'ala ma kota', []);
  assert.equal(variants.length, 3);
});

test('ignores prose wrapped around the JSON object', () => {
  const raw = 'Sure! Here you go:\n' + THREE + '\nHope that helps.';
  const variants = parseVariants(raw, DEFAULT_LIMITS, 'ala ma kota', []);
  assert.equal(variants.length, 3);
});

test('rejects output with no JSON object', () => {
  assert.throws(
    () => parseVariants('I cannot help with that.', DEFAULT_LIMITS, 'x', []),
    VariantParseError,
  );
});

test('rejects malformed JSON', () => {
  assert.throws(
    () => parseVariants('{"variants":[{"text":"a"', DEFAULT_LIMITS, 'x', []),
    VariantParseError,
  );
});

test('rejects a missing variants array', () => {
  assert.throws(
    () => parseVariants('{"result":"nope"}', DEFAULT_LIMITS, 'x', []),
    VariantParseError,
  );
});

test('skips empty and whitespace-only variants', () => {
  const raw = '{"variants":[{"label":"A","text":"   "},{"label":"B","text":"Dobra."}]}';
  const variants = parseVariants(raw, DEFAULT_LIMITS, 'zle', []);
  assert.equal(variants.length, 1);
  assert.equal(variants[0].text, 'Dobra.');
});

test('skips a variant identical to the input', () => {
  const raw = '{"variants":[{"label":"A","text":"ala ma kota"},' +
    '{"label":"B","text":"Ala ma kota."}]}';
  const variants = parseVariants(raw, DEFAULT_LIMITS, 'ala ma kota', []);
  assert.equal(variants.length, 1);
  assert.equal(variants[0].text, 'Ala ma kota.');
});

test('skips a variant that exceeds the length limit', () => {
  const long = 'x'.repeat(DEFAULT_LIMITS.maxChars + 1);
  const raw = '{"variants":[{"label":"A","text":"' + long + '"},' +
    '{"label":"B","text":"Krotkie."}]}';
  const variants = parseVariants(raw, DEFAULT_LIMITS, 'zle', []);
  assert.equal(variants.length, 1);
  assert.equal(variants[0].text, 'Krotkie.');
});

test('caps the number of variants', () => {
  const raw = '{"variants":[{"text":"a."},{"text":"b."},{"text":"c."},{"text":"d."}]}';
  const variants = parseVariants(raw, { maxVariants: 2, maxChars: 600 }, 'zle', []);
  assert.equal(variants.length, 2);
});

test('skips variants containing forbidden tokens', () => {
  const raw = '{"variants":[{"text":"tajne [[X_1]]"},{"text":"Czyste."}]}';
  const variants = parseVariants(raw, DEFAULT_LIMITS, 'zle', ['[[X_1]]']);
  assert.equal(variants.length, 1);
  assert.equal(variants[0].text, 'Czyste.');
});

test('drops duplicate variants', () => {
  const raw = '{"variants":[{"text":"To samo."},{"text":"To samo."}]}';
  const variants = parseVariants(raw, DEFAULT_LIMITS, 'zle', []);
  assert.equal(variants.length, 1);
});

test('defaults the label when the model omits it', () => {
  const raw = '{"variants":[{"text":"Bez etykiety."}]}';
  const variants = parseVariants(raw, DEFAULT_LIMITS, 'zle', []);
  assert.equal(variants[0].label, 'Variant');
});

test('rejects a response where every variant was unusable', () => {
  const raw = '{"variants":[{"text":""},{"text":"   "}]}';
  assert.throws(() => parseVariants(raw, DEFAULT_LIMITS, 'zle', []), VariantParseError);
});

test('stripFences leaves un-fenced text untouched', () => {
  assert.equal(stripFences('  {"a":1}  '), '{"a":1}');
});

test('extractObject keeps only the outermost object', () => {
  assert.equal(extractObject('noise {"a":{"b":1}} tail'), '{"a":{"b":1}}');
});
