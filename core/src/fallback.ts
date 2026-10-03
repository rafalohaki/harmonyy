/**
 * Deterministic offline engine.
 *
 * This is what the keyboard uses when the network, the timeout or the model
 * fails. It is deliberately modest: it fixes what rules can fix and says so in
 * the UI, instead of pretending to be the model. A working narrow answer beats
 * a confident wrong one.
 *
 * No lookbehind and no callback-based replace: both are portable-hostile.
 */

import type { RewriteRequest, Variant } from './contracts.ts';

/** Filler that makes telegraphic or anxious writing harder to read. */
const FILLERS: string[] = [
  'po prostu',
  'właściwie',
  'tak jakby',
  'generalnie',
  'w sumie',
  'jakby',
  'no więc',
  'szczerze mówiąc',
];

/** Imperative to polite infinitive, for the small set of very common verbs. */
const POLITE_VERBS: string[][] = [
  ['daj', 'przesłać'],
  ['wyślij', 'wysłać'],
  ['wyslij', 'wysłać'],
  ['zrób', 'wykonać'],
  ['zrob', 'wykonać'],
  ['sprawdź', 'sprawdzić'],
  ['sprawdz', 'sprawdzić'],
  ['napisz', 'napisać'],
  ['zadzwoń', 'zadzwonić'],
  ['zadzwon', 'zadzwonić'],
  ['przyjdź', 'przyjść'],
  ['przyjdz', 'przyjść'],
  ['powiedz', 'przekazać'],
  ['popraw', 'poprawić'],
  ['zmień', 'zmienić'],
  ['zmien', 'zmienić'],
];

/** Collapse whitespace and trim. */
export function tidy(text: string): string {
  return text.replace(/\s+/g, ' ').trim();
}

/** Capitalise the first letter and the first letter after . ! ? */
export function capitaliseSentences(text: string): string {
  let result: string = '';
  let atStart: boolean = true;

  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    if (atStart && ch !== ' ') {
      result = result + ch.toUpperCase();
      atStart = false;
    } else {
      result = result + ch;
    }
    if (ch === '.' || ch === '!' || ch === '?') {
      atStart = true;
    }
  }
  return result;
}

/** Ensure the text ends with terminal punctuation. */
export function ensureTerminalPunctuation(text: string): string {
  const trimmed: string = text.trim();
  if (trimmed.length === 0) {
    return trimmed;
  }
  const last: string = trimmed.charAt(trimmed.length - 1);
  if (last === '.' || last === '!' || last === '?') {
    return trimmed;
  }
  return trimmed + '.';
}

/** Split into sentences without a lookbehind assertion. */
export function splitSentences(text: string): string[] {
  const out: string[] = [];
  let current: string = '';

  for (let i: number = 0; i < text.length; i++) {
    const ch: string = text.charAt(i);
    current = current + ch;
    if (ch === '.' || ch === '!' || ch === '?') {
      const piece: string = current.trim();
      if (piece.length > 0) {
        out.push(piece);
      }
      current = '';
    }
  }

  const tail: string = current.trim();
  if (tail.length > 0) {
    out.push(tail);
  }
  return out;
}

/** Remove filler words. Case-insensitive, boundary-aware. */
export function removeFillers(text: string): string {
  let result: string = text;
  for (let i: number = 0; i < FILLERS.length; i++) {
    const filler: string = FILLERS[i];
    const escaped: string = filler.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const pattern: RegExp = new RegExp('(^|[\\s,])' + escaped + '(?=[\\s,]|$)', 'gi');
    result = result.replace(pattern, ' ');
  }
  return tidy(result).replace(/\s+([,.!?])/g, '$1');
}

/** Split long sentences at commas so each clause stands alone. */
export function splitLongSentences(text: string, maxWords: number): string {
  const sentences: string[] = splitSentences(text);
  const out: string[] = [];

  for (let i: number = 0; i < sentences.length; i++) {
    const sentence: string = sentences[i];
    if (countWords(sentence) <= maxWords) {
      out.push(sentence);
      continue;
    }
    const parts: string[] = sentence.split(/,\s*/);
    for (let p: number = 0; p < parts.length; p++) {
      const part: string = parts[p].trim();
      if (part.length > 0) {
        out.push(ensureTerminalPunctuation(capitaliseSentences(part)));
      }
    }
  }
  return out.join(' ');
}

function countWords(text: string): number {
  const parts: string[] = text.trim().split(/\s+/);
  let count: number = 0;
  for (let i: number = 0; i < parts.length; i++) {
    if (parts[i].length > 0) {
      count = count + 1;
    }
  }
  return count;
}

/**
 * Soften sentence-initial imperatives with "Proszę".
 * Implemented by inspecting the first word of each sentence rather than by a
 * replace callback, which keeps it portable.
 */
export function softenImperatives(text: string): string {
  const sentences: string[] = splitSentences(text);
  const out: string[] = [];

  for (let i: number = 0; i < sentences.length; i++) {
    const sentence: string = sentences[i];
    const lower: string = sentence.toLowerCase();
    let handled: boolean = false;

    for (let v: number = 0; v < POLITE_VERBS.length; v++) {
      const verb: string = POLITE_VERBS[v][0];
      const infinitive: string = POLITE_VERBS[v][1];
      if (lower === verb || lower.startsWith(verb + ' ')) {
        out.push('Proszę ' + infinitive + sentence.substring(verb.length));
        handled = true;
        break;
      }
    }

    if (!handled) {
      out.push(sentence);
    }
  }
  return out.join(' ');
}

/** Build the offline variants for a request. Always returns three entries. */
export function localVariants(request: RewriteRequest): Variant[] {
  const base: string = ensureTerminalPunctuation(capitaliseSentences(tidy(request.text)));

  if (request.mode === 'plain') {
    const plain: string = ensureTerminalPunctuation(
      capitaliseSentences(splitLongSentences(removeFillers(base), 12)),
    );
    return [
      { label: 'Offline: plain', text: plain },
      { label: 'Offline: shorter', text: shorten(base) },
      { label: 'Offline: cleaned', text: removeFillers(base) },
    ];
  }

  if (request.mode === 'polite') {
    const polite: string = ensureTerminalPunctuation(
      capitaliseSentences(softenImperatives(base)),
    );
    return [
      { label: 'Offline: polite', text: 'Dzień dobry, ' + lowerFirst(polite) },
      {
        label: 'Offline: polite + close',
        text: 'Dzień dobry, ' + lowerFirst(polite) + ' Dziękuję.',
      },
      { label: 'Offline: cleaned', text: base },
    ];
  }

  return [
    { label: 'Offline: corrected', text: base },
    { label: 'Offline: cleaned', text: removeFillers(base) },
    { label: 'Offline: shorter', text: shorten(base) },
  ];
}

function shorten(text: string): string {
  const words: string[] = text.split(/\s+/);
  if (words.length <= 8) {
    return text;
  }
  return ensureTerminalPunctuation(words.slice(0, 8).join(' '));
}

function lowerFirst(text: string): string {
  if (text.length === 0) {
    return text;
  }
  return text.charAt(0).toLowerCase() + text.substring(1);
}
