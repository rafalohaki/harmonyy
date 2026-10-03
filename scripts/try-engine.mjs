#!/usr/bin/env node
/**
 * Exercise the real rewrite engine from the terminal, before any device exists.
 *
 * Why this exists: the engine is the product, and its quality depends on how a
 * real model responds to our prompt. Waiting for a working .hap to discover that
 * the prompt is wrong is the most expensive possible order of operations. This
 * tool reuses the exact shipped core, so what it prints is what the keyboard will
 * show.
 *
 * Three modes:
 *
 *   --mock          start a local OpenAI-shaped server and run against it. Proves
 *                   the whole HTTP path, redaction and restoration included, with
 *                   no credentials and no network.
 *   (no flag)       call the real endpoint using BRIDGE_API_KEY.
 *
 * Credentials are read from the environment and never written anywhere:
 *   BRIDGE_API_KEY   required unless --mock is used
 *   BRIDGE_BASE_URL  default https://api.openai.com/v1
 *   BRIDGE_MODEL     default gpt-4o-mini
 *
 * Usage:
 *   node scripts/try-engine.mjs --mock
 *   BRIDGE_API_KEY=sk-... node scripts/try-engine.mjs
 *   BRIDGE_API_KEY=sk-... node scripts/try-engine.mjs --text "ja chciec isc" --mode plain
 */

import http from 'node:http';

import { DEFAULT_OPTIONS, RewriteEngine } from '../core/src/engine.ts';
import { LlmError } from '../core/src/contracts.ts';
import { buildChatRequestBody, parseChatCompletion, DEFAULT_TEMPERATURE }
  from '../core/src/openai.ts';

// ---------------------------------------------------------------------------
// Transport
// ---------------------------------------------------------------------------

class FetchTransport {
  constructor(baseUrl, model, apiKey) {
    this.baseUrl = baseUrl;
    this.model = model;
    this.apiKey = apiKey;
  }

  chatUrl() {
    let base = this.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base.endsWith('/chat/completions') ? base : `${base}/chat/completions`;
  }

  async complete(messages, timeoutMs) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(this.chatUrl(), {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`,
        },
        body: buildChatRequestBody(this.model, messages, DEFAULT_TEMPERATURE),
        signal: controller.signal,
      });
      const body = await response.text();
      if (response.status === 401 || response.status === 403) {
        throw new LlmError('auth', `HTTP ${response.status}`, response.status);
      }
      if (!response.ok) {
        throw new LlmError(
          'http',
          `HTTP ${response.status}: ${body.substring(0, 200)}`,
          response.status,
        );
      }
      return parseChatCompletion(body);
    } catch (error) {
      if (error instanceof LlmError) {
        throw error;
      }
      if (error.name === 'AbortError') {
        throw new LlmError('timeout', 'request aborted', 0);
      }
      throw new LlmError('transport', String(error.message ?? error), 0);
    } finally {
      clearTimeout(timer);
    }
  }
}

// ---------------------------------------------------------------------------
// Mock model
// ---------------------------------------------------------------------------

/**
 * A deliberately dumb stand-in that is nevertheless honest about the contract:
 * it answers with the requested JSON shape and copies any [[KIND_n]] placeholder
 * it was given, verbatim. That is enough to prove redaction, restoration and the
 * parser, which is what the mock is for.
 */
function mockCompletion(userText) {
  const placeholders = userText.match(/\[\[[A-Z]+_\d+\]\]/g) ?? [];
  const tail = placeholders.length > 0 ? ` ${placeholders.join(' ')}` : '';
  const cleaned = userText.replace(/\[\[[A-Z]+_\d+\]\]/g, '').replace(/\s+/g, ' ').trim();
  const words = cleaned.split(' ').filter(Boolean);

  const variants = [
    { label: 'Correct', text: `${capitalise(words.slice(0, 12).join(' '))}${tail}.` },
    { label: 'Plain', text: `${capitalise(words.slice(0, 7).join(' '))}${tail}.` },
    { label: 'Polite', text: `Dzień dobry, ${words.slice(0, 9).join(' ')}${tail}. Dziękuję.` },
  ];
  return JSON.stringify({ choices: [{ message: { role: 'assistant', content: JSON.stringify({ variants }) } }] });
}

function capitalise(text) {
  return text.length === 0 ? text : text.charAt(0).toUpperCase() + text.substring(1);
}

/** Minimal OpenAI-compatible server. */
function startMockServer() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let raw = '';
      req.on('data', (chunk) => { raw += chunk; });
      req.on('end', () => {
        let userText = '';
        try {
          const body = JSON.parse(raw);
          for (const message of body.messages ?? []) {
            if (message.role === 'user') {
              const marker = 'User text:';
              const at = message.content.indexOf(marker);
              if (at !== -1) {
                userText = message.content
                  .substring(at + marker.length)
                  .split('Reply with JSON only')[0]
                  .trim();
              }
            }
          }
        } catch {
          // fall through with empty input
        }
        const payload = mockCompletion(userText);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(payload);
      });
    });
    server.listen(0, '127.0.0.1', () => {
      resolve({ server, port: server.address().port });
    });
  });
}

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

const SAMPLES = [
  { text: 'ja chciec jutro przyjsc na spotkanie o 10', mode: 'correct' },
  { text: 'no więc po prostu potrzebuje tego dokumentu, bo inaczej nie moge skonczyc sprawy', mode: 'plain' },
  { text: 'wyślij raport dzisiaj', mode: 'polite' },
  { text: 'napisz do jan.kowalski@example.com albo zadzwon +48 123 456 789', mode: 'correct' },
];

function parseArgs(argv) {
  const options = { mock: false, text: '', mode: 'correct', help: false, bad: '' };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--mock') options.mock = true;
    else if (arg === '--text') options.text = argv[++i] ?? '';
    else if (arg === '--mode') options.mode = argv[++i] ?? 'correct';
    else if (arg === '--help' || arg === '-h') options.help = true;
    else options.bad = arg;
  }
  return options;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.bad.length > 0) {
    console.error(`Unknown argument: ${options.bad}`);
    process.exitCode = 2;
    return;
  }
  if (options.help) {
    console.log('See the header of this file for usage.');
    return;
  }
  if (options.mode !== 'correct' && options.mode !== 'plain' && options.mode !== 'polite') {
    console.error(`Unknown mode: ${options.mode} (expected correct, plain or polite)`);
    process.exitCode = 2;
    return;
  }

  let mock = null;
  let baseUrl = process.env.BRIDGE_BASE_URL ?? 'https://api.openai.com/v1';
  let model = process.env.BRIDGE_MODEL ?? 'gpt-4o-mini';
  let apiKey = process.env.BRIDGE_API_KEY ?? '';

  if (options.mock) {
    mock = await startMockServer();
    baseUrl = `http://127.0.0.1:${mock.port}/v1`;
    apiKey = 'mock-key';
    model = 'mock-model';
    console.log(`mock model listening on ${baseUrl}\n`);
  } else if (apiKey.length === 0) {
    console.error('BRIDGE_API_KEY is not set. Use --mock to run without credentials,');
    console.error('or:  BRIDGE_API_KEY=sk-... node scripts/try-engine.mjs');
    process.exitCode = 2;
    return;
  }

  const transport = new FetchTransport(baseUrl, model, apiKey);
  const engine = new RewriteEngine(transport, DEFAULT_OPTIONS, () => Date.now());

  const cases = options.text.length > 0
    ? [{ text: options.text, mode: options.mode }]
    : SAMPLES;

  let remote = 0;
  let local = 0;
  let redacted = 0;
  const latencies = [];

  for (const testCase of cases) {
    const outcome = await engine.rewrite({
      text: testCase.text,
      mode: testCase.mode,
      contextHint: 'a casual messaging app (com.example.messenger)',
      locale: 'pl-PL',
    });

    if (outcome.source === 'remote') remote++; else local++;
    redacted += outcome.redactedCount;
    if (outcome.latencyMs > 0) latencies.push(outcome.latencyMs);

    console.log(`mode      : ${testCase.mode}`);
    console.log(`input     : ${testCase.text}`);
    console.log(`source    : ${outcome.source}${outcome.fallbackReason ? `  (${outcome.fallbackReason})` : ''}`);
    console.log(`hidden    : ${outcome.redactedCount} item(s) withheld from the model`);
    console.log(`latency   : ${outcome.latencyMs} ms`);
    for (const variant of outcome.variants) {
      console.log(`  [${variant.label}] ${variant.text}`);
    }
    console.log('');
  }

  console.log('--- summary ---');
  console.log(`cases          : ${cases.length}`);
  console.log(`answered by    : remote ${remote}, local fallback ${local}`);
  console.log(`items withheld : ${redacted}`);
  if (latencies.length > 0) {
    const average = Math.round(latencies.reduce((a, b) => a + b, 0) / latencies.length);
    console.log(`latency        : avg ${average} ms, max ${Math.max(...latencies)} ms`);
  }

  // The failure path is part of the product, so the tool demonstrates it too,
  // with a transport that always fails rather than a bad credential: that is the
  // branch the keyboard will actually take when the network drops.
  console.log('');
  console.log('--- failure path: the engine must degrade, not crash ---');
  const failingTransport = {
    async complete() {
      throw new LlmError('timeout', 'simulated failure', 0);
    },
  };
  const failingEngine = new RewriteEngine(failingTransport, DEFAULT_OPTIONS, () => Date.now());
  const degraded = await failingEngine.rewrite({
    text: 'ja chciec isc do domu',
    mode: 'correct',
    contextHint: '',
    locale: 'pl-PL',
  });
  console.log(`source  : ${degraded.source}`);
  console.log(`reason  : ${degraded.fallbackReason}`);
  console.log(`variants: ${degraded.variants.length} from the offline engine`);
  console.log(`first   : ${degraded.variants.length > 0 ? degraded.variants[0].text : '(none)'}`);

  if (mock) {
    mock.server.close();
  }
}

main().catch((error) => {
  console.error('unexpected failure:', error);
  process.exitCode = 1;
});
