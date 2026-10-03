/**
 * Offline-only mode.
 *
 * The promise is absolute: with it on, no request is made at all. These tests
 * check the promise rather than the mechanism, so they assert on the transport
 * never being called, not merely on the outcome looking local.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { DEFAULT_OPTIONS, RewriteEngine } from '../src/engine.ts';
import type { EngineOptions } from '../src/engine.ts';
import type { LlmTransport, RewriteRequest } from '../src/contracts.ts';

class RecordingTransport implements LlmTransport {
  calls: number = 0;

  async complete(): Promise<string> {
    this.calls = this.calls + 1;
    return '{"variants":[{"label":"A","text":"should never be used"}]}';
  }
}

function options(forceOffline: boolean): EngineOptions {
  return {
    timeoutMs: DEFAULT_OPTIONS.timeoutMs,
    maxAttempts: DEFAULT_OPTIONS.maxAttempts,
    limits: DEFAULT_OPTIONS.limits,
    redactionEnabled: DEFAULT_OPTIONS.redactionEnabled,
    forceOffline: forceOffline,
  };
}

function request(text: string): RewriteRequest {
  return { text: text, mode: 'correct', contextHint: '', locale: 'pl-PL' };
}

test('offline-only never reaches the transport', async () => {
  const transport = new RecordingTransport();
  const engine = new RewriteEngine(transport, options(true), () => Date.now());

  const outcome = await engine.rewrite(request('ala ma kota'));

  assert.equal(transport.calls, 0, 'the promise is that no request is made');
  assert.equal(outcome.source, 'local');
  assert.equal(outcome.fallbackReason, 'Offline-only mode is on.');
  assert.equal(outcome.variants.length, 3);
});

test('offline-only reports nothing withheld, because nothing leaves the device', async () => {
  const transport = new RecordingTransport();
  const engine = new RewriteEngine(transport, options(true), () => Date.now());

  const outcome = await engine.rewrite(request('napisz do jan@example.com'));

  assert.equal(outcome.redactedCount, 0);
  assert.ok(!outcome.variants[0].text.includes('[[EMAIL_1]]'));
});

test('offline-only still answers in compose mode', async () => {
  const transport = new RecordingTransport();
  const engine = new RewriteEngine(transport, options(true), () => Date.now());

  const outcome = await engine.rewrite({
    text: '',
    mode: 'compose',
    contextHint: '',
    locale: 'pl-PL',
    tokens: ['jeść', 'jutro'],
  });

  assert.equal(transport.calls, 0);
  assert.equal(outcome.variants.length, 3);
});

test('offline-only does not change behaviour when it is off', async () => {
  const transport = new RecordingTransport();
  const engine = new RewriteEngine(transport, options(false), () => Date.now());

  const outcome = await engine.rewrite(request('ala ma kota'));

  assert.equal(transport.calls, 1, 'with the switch off the model is used');
  assert.equal(outcome.source, 'remote');
});
