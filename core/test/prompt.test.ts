/**
 * Prompt contract tests.
 *
 * The prompt is the interface between our code and a model we do not control, so
 * its guarantees are pinned here. The last test in this file is a safety property
 * rather than a formatting one: the user's text must never end up in the system
 * prompt, because that is the message whose content we control absolutely.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  OUTPUT_SCHEMA,
  buildMessages,
  buildRepairMessages,
  buildSystemPrompt,
  buildUserPrompt,
} from '../src/prompt.ts';
import type { RewriteRequest } from '../src/contracts.ts';

const SECRET_TEXT = 'tajny tekst uzytkownika 12345';

function request(hint: string): RewriteRequest {
  return { text: SECRET_TEXT, mode: 'correct', contextHint: hint, locale: 'pl-PL' };
}

test('the system prompt states the output schema', () => {
  assert.ok(buildSystemPrompt().includes(OUTPUT_SCHEMA));
});

test('the system prompt requires placeholders to be copied verbatim', () => {
  const system = buildSystemPrompt();
  assert.ok(system.includes('[[KIND_1]]'), 'placeholder example missing');
  assert.ok(system.includes('Copy them into your output exactly'));
});

test('the system prompt pins the output language to the input', () => {
  assert.ok(buildSystemPrompt().includes('Match the language of the user text'));
});

test('the system prompt forbids markdown and commentary', () => {
  const system = buildSystemPrompt();
  assert.ok(system.includes('No markdown'));
});

test('buildMessages returns exactly a system and a user message', () => {
  const messages = buildMessages(request('Messages'));
  assert.equal(messages.length, 2);
  assert.equal(messages[0].role, 'system');
  assert.equal(messages[1].role, 'user');
});

test('the user prompt carries the text, the locale and the schema', () => {
  const user = buildUserPrompt(request('Messages'));
  assert.ok(user.includes(SECRET_TEXT));
  assert.ok(user.includes('pl-PL'));
  assert.ok(user.includes(OUTPUT_SCHEMA));
});

test('the user prompt names the hosting app when there is a hint', () => {
  const user = buildUserPrompt(request('a casual messaging app (com.ohos.mms)'));
  assert.ok(user.includes('com.ohos.mms'));
  assert.ok(user.includes('match its register'));
});

test('the user prompt omits the register line when there is no hint', () => {
  const user = buildUserPrompt(request(''));
  assert.ok(!user.includes('match its register'));
});

test('the mode selects the instruction', () => {
  const correct: RewriteRequest = {
    text: 'x', mode: 'correct', contextHint: '', locale: 'pl-PL',
  };
  const plain: RewriteRequest = {
    text: 'x', mode: 'plain', contextHint: '', locale: 'pl-PL',
  };
  const polite: RewriteRequest = {
    text: 'x', mode: 'polite', contextHint: '', locale: 'pl-PL',
  };
  assert.ok(buildUserPrompt(correct).includes('Fix spelling'));
  assert.ok(buildUserPrompt(plain).includes('plain, easy-to-read'));
  assert.ok(buildUserPrompt(polite).includes('polite, professional register'));
});

test('the repair prompt is strictly more explicit and does not echo the bad answer', () => {
  const messages = buildRepairMessages(request(''));
  assert.equal(messages.length, 3);
  assert.equal(messages[2].role, 'user');
  assert.ok(messages[2].content.includes('JSON only'));
  assert.ok(messages[2].content.includes('was not valid JSON'));
});

test('SAFETY: the user text never appears in the system prompt', () => {
  const messages = buildMessages(request('Messages'));
  assert.ok(!messages[0].content.includes(SECRET_TEXT),
    'the system prompt must not embed user text');
  const repair = buildRepairMessages(request('Messages'));
  assert.ok(!repair[0].content.includes(SECRET_TEXT));
});

test('SAFETY: the system prompt is identical regardless of the user text', () => {
  const a = buildSystemPrompt();
  const b = buildMessages({
    text: 'calkiem inny tekst', mode: 'polite', contextHint: 'x', locale: 'en-US',
  })[0].content;
  assert.equal(a, b);
});
