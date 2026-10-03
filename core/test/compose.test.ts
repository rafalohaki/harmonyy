/**
 * Compose mode tests.
 *
 * Compose is the mode for users who cannot type at all: they pick concepts and the
 * model turns them into a sentence. The tests pin three things: that the concepts
 * reach the prompt and the editor text does not, that an empty pick never reaches
 * the network, and that the offline path is labelled as offline rather than passed
 * off as composed language.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { DEFAULT_OPTIONS, RewriteEngine } from '../src/engine.ts';
import type { LlmMessage, LlmTransport, RewriteRequest } from '../src/contracts.ts';
import { LlmError } from '../src/contracts.ts';
import { buildMessages, buildUserPrompt } from '../src/prompt.ts';
import { localVariants } from '../src/fallback.ts';
import { REWRITE_MODES, modeLabel } from '../src/contracts.ts';

const TOKENS: string[] = ['jeść', 'jutro', 'razem'];

function compose(tokens: string[]): RewriteRequest {
  return {
    text: '',
    mode: 'compose',
    contextHint: 'a casual messaging app (com.example.messenger)',
    locale: 'pl-PL',
    tokens: tokens,
  };
}

class FakeTransport implements LlmTransport {
  calls: LlmMessage[][] = [];
  private steps: (string | Error)[];

  constructor(steps: (string | Error)[]) {
    this.steps = steps;
  }

  async complete(messages: LlmMessage[]): Promise<string> {
    this.calls.push(messages);
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

test('compose is a declared mode with a label', () => {
  assert.ok(REWRITE_MODES.includes('compose'));
  assert.equal(modeLabel('compose'), 'Compose');
});

test('the compose prompt carries the concepts and no user text', () => {
  const user = buildUserPrompt(compose(TOKENS));
  assert.ok(user.includes('jeść, jutro, razem'), 'the concepts must be present');
  assert.ok(user.includes('pictograms') || user.includes('Compose the sentence'));
  assert.ok(!user.includes('User text:'), 'compose must not present an editor text');
});

test('the compose prompt survives an empty concept list', () => {
  const user = buildUserPrompt(compose([]));
  assert.ok(user.includes('Concepts chosen by the user'));
});

test('compose sends the concepts to the model and returns its variants', async () => {
  const raw = '{"variants":[{"label":"A","text":"Chcę zjeść jutro razem."}]}';
  const transport = new FakeTransport([raw]);
  const engine = new RewriteEngine(transport, DEFAULT_OPTIONS, () => Date.now());

  const outcome = await engine.rewrite(compose(TOKENS));

  assert.equal(outcome.source, 'remote');
  assert.equal(outcome.variants.length, 1);
  assert.equal(outcome.variants[0].text, 'Chcę zjeść jutro razem.');
  assert.ok(transport.calls[0][1].content.includes('jeść, jutro, razem'));
});

test('compose with nothing picked never reaches the network', async () => {
  const transport = new FakeTransport(['should not be called']);
  const engine = new RewriteEngine(transport, DEFAULT_OPTIONS, () => Date.now());

  const outcome = await engine.rewrite(compose([]));

  assert.equal(transport.calls.length, 0);
  assert.equal(outcome.variants.length, 0);
  assert.equal(outcome.source, 'local');
});

test('the offline compose path is labelled as offline', () => {
  const variants = localVariants(compose(TOKENS));
  assert.equal(variants.length, 3);
  for (let i = 0; i < variants.length; i++) {
    const v = variants[i];
    assert.ok(v.label.toLowerCase().includes('offline'),
      'an offline result must say so: ' + v.label);
    assert.ok(v.text.includes('jeść'), 'the concepts must survive the fallback');
  }
});

test('compose falls back offline when the model fails', async () => {
  const transport = new FakeTransport([new LlmError('timeout', 'slow', 0)]);
  const engine = new RewriteEngine(transport, DEFAULT_OPTIONS, () => Date.now());

  const outcome = await engine.rewrite(compose(TOKENS));

  assert.equal(outcome.source, 'local');
  assert.equal(outcome.fallbackReason, 'The model timed out.');
  assert.equal(outcome.variants.length, 3);
  assert.ok(outcome.variants[0].text.includes('jeść'));
});

test('compose does not leak the concept list into the system prompt', () => {
  const messages = buildMessages(compose(TOKENS));
  assert.ok(!messages[0].content.includes('jeść'));
});
