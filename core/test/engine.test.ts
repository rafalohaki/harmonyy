/**
 * Engine tests. Every AI failure mode the product claims to survive is
 * reproduced here with a scripted transport, so the claim is verified rather
 * than asserted.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import type { EngineOptions } from '../src/engine.ts';
import { DEFAULT_OPTIONS, RewriteEngine } from '../src/engine.ts';
import type { LlmMessage, LlmTransport, RewriteRequest } from '../src/contracts.ts';
import { LlmError } from '../src/contracts.ts';

/** Scripted transport: returns or throws each queued step in turn. */
class FakeTransport implements LlmTransport {
  private steps: (string | Error)[];
  calls: LlmMessage[][] = [];
  timeouts: number[] = [];

  constructor(steps: (string | Error)[]) {
    this.steps = steps;
  }

  async complete(messages: LlmMessage[], timeoutMs: number): Promise<string> {
    this.calls.push(messages);
    this.timeouts.push(timeoutMs);
    const step = this.steps.length > 0 ? this.steps.shift() : undefined;
    if (step === undefined) {
      throw new Error('FakeTransport exhausted');
    }
    if (step instanceof Error) {
      throw step;
    }
    return step;
  }
}

function options(overrides: Partial<EngineOptions>): EngineOptions {
  return {
    timeoutMs: overrides.timeoutMs ?? DEFAULT_OPTIONS.timeoutMs,
    maxAttempts: overrides.maxAttempts ?? DEFAULT_OPTIONS.maxAttempts,
    limits: overrides.limits ?? DEFAULT_OPTIONS.limits,
    redactionEnabled: overrides.redactionEnabled ?? DEFAULT_OPTIONS.redactionEnabled,
  };
}

function request(text: string, mode: RewriteRequest['mode']): RewriteRequest {
  return { text: text, mode: mode, contextHint: 'Messages', locale: 'pl-PL' };
}

const VALID = '{"variants":[{"label":"Poprawnie","text":"Ala ma kota."},' +
  '{"label":"Krocej","text":"Ala, kot."}]}';

/** Monotonic clock so latency is deterministic. */
function fakeClock(): () => number {
  let t = 0;
  return (): number => {
    t = t + 7;
    return t;
  };
}

test('returns remote variants on success', async () => {
  const transport = new FakeTransport([VALID]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());
  const outcome = await engine.rewrite(request('ala ma kota', 'correct'));

  assert.equal(outcome.source, 'remote');
  assert.equal(outcome.fallbackReason, '');
  assert.equal(outcome.variants.length, 2);
  assert.equal(outcome.variants[0].text, 'Ala ma kota.');
  assert.equal(transport.calls.length, 1);
});

test('withholds personal data from the model and restores it locally', async () => {
  const raw = '{"variants":[{"label":"Poprawnie","text":"Napisz do [[EMAIL_1]] dzisiaj."}]}';
  const transport = new FakeTransport([raw]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  const outcome = await engine.rewrite(request('napisz do jan@example.com', 'correct'));

  assert.equal(outcome.source, 'remote');
  assert.equal(outcome.redactedCount, 1);
  assert.equal(outcome.variants[0].text, 'Napisz do jan@example.com dzisiaj.');

  // The claim that matters: the address was never in the outgoing request.
  const sent = transport.calls[0][1].content;
  assert.ok(sent.includes('[[EMAIL_1]]'), 'placeholder should be sent');
  assert.ok(!sent.includes('jan@example.com'), 'real address must not be sent');
});

test('falls back to the local engine on timeout', async () => {
  const transport = new FakeTransport([new LlmError('timeout', 'slow', 0)]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  const outcome = await engine.rewrite(request('ala ma kota', 'correct'));

  assert.equal(outcome.source, 'local');
  assert.equal(outcome.fallbackReason, 'The model timed out.');
  assert.equal(outcome.variants.length, 3);
  assert.equal(transport.calls.length, 1, 'a timeout must not be retried');
});

test('falls back on an HTTP error and names the status', async () => {
  const transport = new FakeTransport([new LlmError('http', 'server', 503)]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  const outcome = await engine.rewrite(request('ala ma kota', 'plain'));

  assert.equal(outcome.source, 'local');
  assert.equal(outcome.fallbackReason, 'The model service returned HTTP 503.');
});

test('falls back on a rejected API key', async () => {
  const transport = new FakeTransport([new LlmError('auth', 'bad key', 401)]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  const outcome = await engine.rewrite(request('ala ma kota', 'correct'));
  assert.equal(outcome.fallbackReason, 'The API key was rejected.');
});

test('repairs a malformed answer and succeeds on the second attempt', async () => {
  const transport = new FakeTransport(['I am sorry, I cannot do that.', VALID]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  const outcome = await engine.rewrite(request('ala ma kota', 'correct'));

  assert.equal(outcome.source, 'remote');
  assert.equal(transport.calls.length, 2);
  // The repair prompt must be strictly more explicit than the first one.
  assert.equal(transport.calls[1].length, 3);
  assert.ok(transport.calls[1][2].content.includes('JSON only'));
});

test('falls back after exhausting the repair attempts', async () => {
  const transport = new FakeTransport(['nope', 'still nope']);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  const outcome = await engine.rewrite(request('ala ma kota', 'correct'));

  assert.equal(outcome.source, 'local');
  assert.equal(outcome.fallbackReason, 'The model answer was unusable.');
  assert.equal(transport.calls.length, 2);
});

test('rejects an answer that invents placeholder tokens', async () => {
  const raw = '{"variants":[{"label":"A","text":"cos [[SECRET_9]] tutaj"}]}';
  const transport = new FakeTransport([raw, raw]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  const outcome = await engine.rewrite(request('ala ma kota', 'correct'));
  assert.equal(outcome.source, 'local');
});

test('rejects an answer that drops a private placeholder', async () => {
  const raw = '{"variants":[{"label":"A","text":"Napisz do kogos dzisiaj."}]}';
  const transport = new FakeTransport([raw, raw]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  const outcome = await engine.rewrite(request('napisz do jan@example.com', 'correct'));

  assert.equal(outcome.source, 'local');
  assert.equal(outcome.redactedCount, 1);
  // Restoring was impossible, so nothing personal may leak into the fallback.
  assert.ok(!outcome.variants[0].text.includes('[[EMAIL_1]]'));
});

test('refuses to call the network for empty input', async () => {
  const transport = new FakeTransport([VALID]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  const outcome = await engine.rewrite(request('   ', 'correct'));

  assert.equal(transport.calls.length, 0);
  assert.equal(outcome.variants.length, 0);
  assert.equal(outcome.source, 'local');
});

test('skips redaction when it is disabled', async () => {
  const raw = '{"variants":[{"label":"A","text":"Napisz do jan@example.com teraz."}]}';
  const transport = new FakeTransport([raw]);
  const engine = new RewriteEngine(transport, options({ redactionEnabled: false }), fakeClock());

  const outcome = await engine.rewrite(request('napisz do jan@example.com', 'correct'));

  assert.equal(outcome.redactedCount, 0);
  assert.ok(transport.calls[0][1].content.includes('jan@example.com'));
});

test('passes the configured timeout to the transport', async () => {
  const transport = new FakeTransport([VALID]);
  const engine = new RewriteEngine(transport, options({ timeoutMs: 4321 }), fakeClock());

  await engine.rewrite(request('ala ma kota', 'correct'));
  assert.equal(transport.timeouts[0], 4321);
});

test('reports a non-zero latency for a remote answer', async () => {
  const transport = new FakeTransport([VALID]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  const outcome = await engine.rewrite(request('ala ma kota', 'correct'));
  assert.ok(outcome.latencyMs > 0, 'latency should be measured, got ' + outcome.latencyMs);
});

test('propagates the request mode into the prompt instruction', async () => {
  const transport = new FakeTransport([VALID]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  await engine.rewrite(request('ala ma kota', 'plain'));
  const sent = transport.calls[0][1].content;
  assert.ok(sent.includes('plain, easy-to-read'), 'plain-mode instruction missing');
});

test('includes the app context hint in the prompt', async () => {
  const transport = new FakeTransport([VALID]);
  const engine = new RewriteEngine(transport, options({}), fakeClock());

  await engine.rewrite(request('ala ma kota', 'correct'));
  assert.ok(transport.calls[0][1].content.includes('Messages'));
});
