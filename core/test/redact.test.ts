/**
 * Redaction tests. These are the tests that protect the privacy claim, so they
 * cover both directions of failure: leaking a real value, and mangling the text
 * by redacting something that is not private.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { Redactor, DEFAULT_RULES, replaceAllLiteral } from '../src/redact.ts';
import type { PlaceholderEntry } from '../src/contracts.ts';

function makeRedactor(): Redactor {
  return new Redactor(DEFAULT_RULES);
}

test('redacts an e-mail address', () => {
  const r = makeRedactor();
  const out = r.redact('Napisz do jan.kowalski@example.com dzisiaj');
  assert.equal(out.count, 1);
  assert.ok(out.text.includes('[[EMAIL_1]]'));
  assert.ok(!out.text.includes('jan.kowalski@example.com'));
});

test('redacts a card number as a card, not as a phone number', () => {
  const r = makeRedactor();
  const out = r.redact('karta 4111 1111 1111 1111 prosze');
  assert.equal(out.count, 1);
  assert.equal(out.map[0].kind, 'CARD');
});

test('redacts a Polish phone number including its leading plus', () => {
  const r = makeRedactor();
  const out = r.redact('zadzwon na +48 123 456 789 jutro');
  assert.equal(out.count, 1);
  assert.equal(out.map[0].kind, 'PHONE');
  // The regression this guards: a dangling "+" left in the scrubbed text.
  assert.ok(!out.text.includes('+'));
  assert.equal(out.map[0].original, '+48 123 456 789');
});

test('redacts an unformatted nine-digit phone number', () => {
  const r = makeRedactor();
  const out = r.redact('tel 123456789 ok');
  assert.equal(out.count, 1);
  assert.equal(out.map[0].kind, 'PHONE');
});

test('redacts a PESEL', () => {
  const r = makeRedactor();
  const out = r.redact('pesel 44051401359 koniec');
  assert.equal(out.count, 1);
  assert.equal(out.map[0].kind, 'PESEL');
});

test('redacts a Polish IBAN', () => {
  const r = makeRedactor();
  const out = r.redact('konto PL61 1090 1014 0000 0712 1981 2874 bank');
  assert.equal(out.count, 1);
  assert.equal(out.map[0].kind, 'IBAN');
});

test('redacts a URL', () => {
  const r = makeRedactor();
  const out = r.redact('zobacz https://example.com/private?token=abc teraz');
  assert.equal(out.count, 1);
  assert.equal(out.map[0].kind, 'URL');
});

test('does not mangle plain years written next to each other', () => {
  const r = makeRedactor();
  const out = r.redact('raport za 2024 2025 gotowy');
  assert.equal(out.count, 0);
  assert.equal(out.text, 'raport za 2024 2025 gotowy');
});

test('does not split a longer digit run into a partial phone number', () => {
  const r = makeRedactor();
  const out = r.redact('numer 1234567890123456 koniec');
  // Sixteen digits is a card, and it must be removed whole.
  assert.equal(out.count, 1);
  assert.equal(out.map[0].kind, 'CARD');
  assert.equal(out.map[0].original.length, 16);
});

test('assigns distinct placeholders to multiple values of the same kind', () => {
  const r = makeRedactor();
  const out = r.redact('a@b.com oraz c@d.com');
  assert.equal(out.count, 2);
  assert.notEqual(out.map[0].placeholder, out.map[1].placeholder);
});

test('restores a round trip exactly', () => {
  const r = makeRedactor();
  const original = 'Napisz do jan@example.com albo na +48 123 456 789';
  const out = r.redact(original);
  const restored = r.restore(out.text, out.map);
  assert.equal(restored, original);
});

test('restore is not confused by placeholder prefixes', () => {
  const r = makeRedactor();
  const map: PlaceholderEntry[] = [
    { placeholder: '[[EMAIL_1]]', original: 'a@b.com', kind: 'EMAIL' },
    { placeholder: '[[EMAIL_10]]', original: 'x@y.com', kind: 'EMAIL' },
  ];
  const text = 'pisz do [[EMAIL_10]] nie do [[EMAIL_1]]';
  const restored = r.restore(text, map);
  assert.equal(restored, 'pisz do x@y.com nie do a@b.com');
});

test('reports placeholders the model dropped', () => {
  const r = makeRedactor();
  const out = r.redact('napisz do jan@example.com');
  const missing = r.missingPlaceholders('napisz do kogos', out.map);
  assert.deepEqual(missing, ['[[EMAIL_1]]']);
});

test('reports placeholders the model invented', () => {
  const r = makeRedactor();
  const out = r.redact('napisz do jan@example.com');
  const unknown = r.unknownPlaceholders('napisz do [[EMAIL_1]] i [[SECRET_7]]', out.map);
  assert.deepEqual(unknown, ['[[SECRET_7]]']);
});

test('literal replace-all treats the needle as text, not as a pattern', () => {
  assert.equal(replaceAllLiteral('a.b a.b', 'a.b', 'X'), 'X X');
});
