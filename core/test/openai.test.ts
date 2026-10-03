/**
 * Tests for the OpenAI-compatible wire format.
 *
 * The point of these tests is that a different provider, or a proxy, or an error
 * page, must never reach the keyboard as a half-parsed answer. Each malformed
 * shape is enumerated rather than assumed away.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  DEFAULT_TEMPERATURE,
  buildChatRequestBody,
  parseChatCompletion,
} from '../src/openai.ts';
import { LlmError } from '../src/contracts.ts';
import type { LlmMessage } from '../src/contracts.ts';

function ok(content: string): string {
  return '{"choices":[{"message":{"role":"assistant","content":' +
    JSON.stringify(content) + '}}]}';
}

test('buildChatRequestBody produces the expected shape', () => {
  const messages: LlmMessage[] = [
    { role: 'system', content: 'be helpful' },
    { role: 'user', content: 'ala ma kota' },
  ];
  const body = buildChatRequestBody('test-model', messages, DEFAULT_TEMPERATURE);
  const parsed = JSON.parse(body);

  assert.equal(parsed.model, 'test-model');
  assert.equal(parsed.stream, false);
  assert.equal(parsed.temperature, DEFAULT_TEMPERATURE);
  assert.equal(parsed.messages.length, 2);
  assert.equal(parsed.messages[0].role, 'system');
  assert.equal(parsed.messages[1].content, 'ala ma kota');
});

test('buildChatRequestBody emits valid JSON for an empty message list', () => {
  const parsed = JSON.parse(buildChatRequestBody('m', [], 0));
  assert.deepEqual(parsed.messages, []);
});

test('parseChatCompletion returns the assistant content', () => {
  assert.equal(parseChatCompletion(ok('Ala ma kota.')), 'Ala ma kota.');
});

test('parseChatCompletion preserves unicode and placeholders', () => {
  const content = 'Napisz do [[EMAIL_1]] — dziś, proszę.';
  assert.equal(parseChatCompletion(ok(content)), content);
});

test('parseChatCompletion rejects a body that is not JSON', () => {
  assert.throws(() => parseChatCompletion('<html>502 Bad Gateway</html>'), LlmError);
});

test('parseChatCompletion rejects JSON without choices', () => {
  assert.throws(() => parseChatCompletion('{"error":{"message":"nope"}}'), LlmError);
});

test('parseChatCompletion rejects a null body', () => {
  assert.throws(() => parseChatCompletion('null'), LlmError);
});

test('parseChatCompletion rejects an empty choices array', () => {
  assert.throws(() => parseChatCompletion('{"choices":[]}'), LlmError);
});

test('parseChatCompletion rejects a choice without a message', () => {
  assert.throws(() => parseChatCompletion('{"choices":[{}]}'), LlmError);
});

test('parseChatCompletion rejects a null message', () => {
  assert.throws(() => parseChatCompletion('{"choices":[{"message":null}]}'), LlmError);
});

test('parseChatCompletion rejects content that is not a string', () => {
  assert.throws(
    () => parseChatCompletion('{"choices":[{"message":{"content":42}}]}'),
    LlmError,
  );
});

test('parseChatCompletion rejects empty content', () => {
  assert.throws(() => parseChatCompletion(ok('')), LlmError);
});

test('parseChatCompletion ignores additional fields', () => {
  const body = '{"id":"x","object":"chat.completion","usage":{"total_tokens":5},' +
    '"choices":[{"index":0,"finish_reason":"stop","message":{"role":"assistant",' +
    '"content":"Dobra."}}]}';
  assert.equal(parseChatCompletion(body), 'Dobra.');
});

test('parseChatCompletion reports failures as transport errors the engine can act on', () => {
  try {
    parseChatCompletion('not json');
    assert.fail('expected a throw');
  } catch (error) {
    assert.ok(error instanceof LlmError);
    assert.equal((error as LlmError).kind, 'transport');
  }
});
