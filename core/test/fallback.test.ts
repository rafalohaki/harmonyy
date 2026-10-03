/**
 * Offline engine tests. The fallback is the safety net for the live demo, so it
 * must always return usable variants and never depend on the network.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  capitaliseSentences,
  ensureTerminalPunctuation,
  localVariants,
  removeFillers,
  softenImperatives,
  splitLongSentences,
  splitSentences,
  tidy,
} from '../src/fallback.ts';
import type { RewriteRequest } from '../src/contracts.ts';

function request(text: string, mode: RewriteRequest['mode']): RewriteRequest {
  return { text: text, mode: mode, contextHint: '', locale: 'pl-PL' };
}

test('tidy collapses whitespace', () => {
  assert.equal(tidy('  ala   ma \n kota '), 'ala ma kota');
});

test('capitaliseSentences uppercases sentence starts', () => {
  assert.equal(capitaliseSentences('ala ma kota. kot ma ale.'), 'Ala ma kota. Kot ma ale.');
});

test('ensureTerminalPunctuation adds a period only when needed', () => {
  assert.equal(ensureTerminalPunctuation('ala ma kota'), 'ala ma kota.');
  assert.equal(ensureTerminalPunctuation('ala ma kota?'), 'ala ma kota?');
  assert.equal(ensureTerminalPunctuation(''), '');
});

test('splitSentences splits on terminal punctuation', () => {
  assert.deepEqual(splitSentences('Ala ma kota. Kot ma ale? Tak!'), [
    'Ala ma kota.',
    'Kot ma ale?',
    'Tak!',
  ]);
});

test('removeFillers drops Polish filler words', () => {
  const out = removeFillers('no więc po prostu idziemy do domu');
  assert.ok(!out.includes('po prostu'));
  assert.ok(!out.includes('no więc'));
  assert.ok(out.includes('idziemy'));
});

test('splitLongSentences breaks a long sentence at commas', () => {
  const long = 'Poszedlem do sklepu, kupilem mleko, chleb, maslo i ser, ' +
    'a potem wrocilem do domu i zrobilem kanapki dla wszystkich.';
  const out = splitLongSentences(long, 8);
  assert.ok(out.includes('.'));
  const parts = splitSentences(out);
  assert.ok(parts.length >= 2, 'expected the sentence to be split');
});

test('softenImperatives turns a leading imperative into a polite request', () => {
  const out = softenImperatives('Wyślij raport dzisiaj.');
  assert.ok(out.startsWith('Proszę wysłać'));
});

test('softenImperatives leaves non-imperative sentences alone', () => {
  const out = softenImperatives('Raport jest gotowy.');
  assert.equal(out, 'Raport jest gotowy.');
});

test('correct mode returns three usable variants', () => {
  const variants = localVariants(request('ala ma kota', 'correct'));
  assert.equal(variants.length, 3);
  for (const v of variants) {
    assert.ok(v.text.length > 0, 'variant text must not be empty');
    assert.ok(v.label.length > 0, 'variant label must not be empty');
  }
  assert.equal(variants[0].text, 'Ala ma kota.');
});

test('plain mode removes fillers', () => {
  const variants = localVariants(request('no więc po prostu ide do domu', 'plain'));
  assert.equal(variants.length, 3);
  assert.ok(!variants[0].text.includes('po prostu'));
});

test('polite mode adds a greeting', () => {
  const variants = localVariants(request('wyślij raport', 'polite'));
  assert.equal(variants.length, 3);
  assert.ok(variants[0].text.startsWith('Dzień dobry'));
  // Polish lowercases after the comma, so compare case-insensitively.
  assert.ok(variants[0].text.toLowerCase().includes('proszę wysłać'));
});

test('every mode tolerates ragged input without throwing', () => {
  const inputs = ['', '   ', '?!', '...', 'a', 'ALA MA KOTA!!!', '123', '😀😀'];
  const modes: RewriteRequest['mode'][] = ['correct', 'plain', 'polite'];
  for (const mode of modes) {
    for (const input of inputs) {
      const variants = localVariants(request(input, mode));
      assert.equal(variants.length, 3, 'mode ' + mode + ' input ' + JSON.stringify(input));
    }
  }
});
