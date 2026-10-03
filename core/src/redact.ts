/**
 * Local PII scrubbing.
 *
 * The rewrite path calls a remote model. Before any text leaves the device we
 * replace the obvious personal identifiers with typed placeholders, and put the
 * real values back locally afterwards. The model never receives them.
 *
 * Scope, stated honestly: this catches structured identifiers, not names,
 * addresses or other identifiers embedded in free prose. It is a mitigation,
 * not a guarantee, and the UI says how many items it hid.
 *
 * Implementation notes:
 * - No lookbehind assertions: ArkTS support is not guaranteed, so boundary
 *   policy is enforced by inspecting neighbouring characters during the scan.
 *   This also fixes the "+48 ..." case, where a leading \b cannot match between
 *   a space and a '+', which would otherwise leave a dangling plus sign.
 * - No replace callbacks: the scan collects match ranges and rewrites the
 *   string back-to-front so that earlier offsets stay valid.
 */

import type { PlaceholderEntry } from './contracts.ts';

/** How the characters around a match must look for it to be accepted. */
export type BoundaryPolicy = 'none' | 'digit' | 'word';

/** One detection rule. Order in DEFAULT_RULES is priority order. */
export interface PiiRule {
  kind: string;
  pattern: RegExp;
  boundary: BoundaryPolicy;
}

/**
 * Ordered so that longer, more specific identifiers are removed before the
 * greedier ones can eat them: a 16-digit card must not become a phone number.
 */
export const DEFAULT_RULES: PiiRule[] = [
  { kind: 'EMAIL', pattern: /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, boundary: 'none' },
  { kind: 'URL', pattern: /https?:\/\/[^\s<>"']+/gi, boundary: 'none' },
  { kind: 'IBAN', pattern: /PL\d{2}(?:\s?\d{4}){6}/gi, boundary: 'word' },
  { kind: 'CARD', pattern: /(?:\d{4}[\s-]?){3}\d{4}/g, boundary: 'digit' },
  { kind: 'PESEL', pattern: /\d{11}/g, boundary: 'digit' },
  // The country prefix is optional: without the outer group a bare nine-digit
  // national number (123456789) would not match at all.
  {
    kind: 'PHONE',
    pattern: /(?:\+?\d{1,3}[\s-]?)?(?:\d{3}[\s-]?){2}\d{3}/g,
    boundary: 'digit',
  },
];

/** Outcome of a scrub. */
export interface RedactionResult {
  text: string;
  count: number;
  map: PlaceholderEntry[];
}

/** Placeholder shape, used to detect tokens we never issued. */
const PLACEHOLDER_SHAPE = /\[\[[A-Z]+_\d+\]\]/;

function isDigit(ch: string): boolean {
  return ch >= '0' && ch <= '9';
}

function isWordChar(ch: string): boolean {
  if (ch.length === 0) {
    return false;
  }
  if (isDigit(ch)) {
    return true;
  }
  const lower: string = ch.toLowerCase();
  const upper: string = ch.toUpperCase();
  // A character is a letter when its case changes under toLowerCase/toUpperCase.
  if (lower !== upper) {
    return true;
  }
  return ch === '_';
}

/** True when the neighbouring characters satisfy the rule's boundary policy. */
function boundaryOk(text: string, start: number, end: number, policy: BoundaryPolicy): boolean {
  if (policy === 'none') {
    return true;
  }

  const before: string = start > 0 ? text.charAt(start - 1) : '';
  const after: string = end < text.length ? text.charAt(end) : '';

  if (policy === 'digit') {
    if (before.length > 0 && isDigit(before)) {
      return false;
    }
    if (after.length > 0 && isDigit(after)) {
      return false;
    }
    return true;
  }

  if (before.length > 0 && isWordChar(before)) {
    return false;
  }
  if (after.length > 0 && isWordChar(after)) {
    return false;
  }
  return true;
}

export class Redactor {
  private rules: PiiRule[];

  constructor(rules: PiiRule[]) {
    this.rules = rules;
  }

  /**
   * Replace every detected identifier with a placeholder.
   * Within each rule, replacement runs back-to-front so that earlier match
   * offsets stay valid while the string is being rewritten.
   */
  redact(input: string): RedactionResult {
    let text: string = input;
    const map: PlaceholderEntry[] = [];
    let count: number = 0;

    for (let r: number = 0; r < this.rules.length; r++) {
      const rule: PiiRule = this.rules[r];
      const scanner: RegExp = new RegExp(rule.pattern.source, 'g');
      const starts: number[] = [];
      const ends: number[] = [];

      let match: RegExpExecArray | null = scanner.exec(text);
      while (match !== null) {
        const start: number = match.index;
        const end: number = match.index + match[0].length;

        if (match[0].length === 0) {
          // Defensive: a zero-length match would spin forever.
          scanner.lastIndex = scanner.lastIndex + 1;
        } else if (boundaryOk(text, start, end, rule.boundary)) {
          starts.push(start);
          ends.push(end);
        } else {
          // Rejected on a boundary violation: continue one character later so a
          // shorter, valid match inside the same run is still considered.
          scanner.lastIndex = start + 1;
        }

        match = scanner.exec(text);
      }

      for (let i: number = starts.length - 1; i >= 0; i--) {
        const start: number = starts[i];
        const end: number = ends[i];
        count = count + 1;
        const placeholder: string = '[[' + rule.kind + '_' + count + ']]';
        const original: string = text.substring(start, end);
        map.push({ placeholder: placeholder, original: original, kind: rule.kind });
        text = text.substring(0, start) + placeholder + text.substring(end);
      }
    }

    return { text: text, count: count, map: map };
  }

  /**
   * Put the real values back. Longer placeholders are substituted first so that
   * [[EMAIL_10]] is never partially rewritten by [[EMAIL_1]].
   */
  restore(text: string, map: PlaceholderEntry[]): string {
    const ordered: PlaceholderEntry[] = map.slice();
    ordered.sort((a: PlaceholderEntry, b: PlaceholderEntry): number => {
      return b.placeholder.length - a.placeholder.length;
    });

    let result: string = text;
    for (let i: number = 0; i < ordered.length; i++) {
      const entry: PlaceholderEntry = ordered[i];
      result = replaceAllLiteral(result, entry.placeholder, entry.original);
    }
    return result;
  }

  /**
   * Placeholders we issued that are absent from the model's answer.
   * If any are missing, restoring would silently lose the user's data, so the
   * caller must treat this as a failed response rather than guess.
   */
  missingPlaceholders(text: string, map: PlaceholderEntry[]): string[] {
    const missing: string[] = [];
    for (let i: number = 0; i < map.length; i++) {
      const entry: PlaceholderEntry = map[i];
      if (!text.includes(entry.placeholder)) {
        missing.push(entry.placeholder);
      }
    }
    return missing;
  }

  /**
   * Placeholder-shaped tokens in the answer that we never issued. A model that
   * invents them is unreliable, so the caller rejects the response.
   */
  unknownPlaceholders(text: string, map: PlaceholderEntry[]): string[] {
    const known: string[] = [];
    for (let i: number = 0; i < map.length; i++) {
      known.push(map[i].placeholder);
    }

    const found: string[] = [];
    const scanner: RegExp = new RegExp(PLACEHOLDER_SHAPE.source, 'g');
    let match: RegExpExecArray | null = scanner.exec(text);
    while (match !== null) {
      if (!known.includes(match[0]) && !found.includes(match[0])) {
        found.push(match[0]);
      }
      match = scanner.exec(text);
    }
    return found;
  }
}

/** Literal, regex-safe replace-all (ArkTS-safe: no replaceAll dependency). */
export function replaceAllLiteral(text: string, needle: string, replacement: string): string {
  if (needle.length === 0) {
    return text;
  }
  return text.split(needle).join(replacement);
}
