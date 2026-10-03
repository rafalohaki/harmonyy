/**
 * Strict validation of model output.
 *
 * Model output is untrusted input. Everything that reaches the UI passes here
 * first: structure, count, length, emptiness, placeholders and duplication.
 * Anything doubtful is rejected so the caller can fall back deliberately rather
 * than display a half-parsed answer.
 */

import type { Variant } from './contracts.ts';
import { VariantParseError } from './contracts.ts';

/** Bounds applied to every accepted variant. */
export interface ParseLimits {
  maxVariants: number;
  maxChars: number;
}

export const DEFAULT_LIMITS: ParseLimits = { maxVariants: 3, maxChars: 600 };

/** Shape we expect from the model after JSON.parse. */
interface VariantDto {
  label?: string;
  text?: string;
}

interface ResponseDto {
  variants?: VariantDto[];
}

/** Drop a leading/trailing markdown fence if the model added one anyway. */
export function stripFences(raw: string): string {
  let text: string = raw.trim();
  if (!text.startsWith('```')) {
    return text;
  }
  const firstBreak: number = text.indexOf('\n');
  if (firstBreak !== -1) {
    text = text.substring(firstBreak + 1);
  }
  const lastFence: number = text.lastIndexOf('```');
  if (lastFence !== -1) {
    text = text.substring(0, lastFence);
  }
  return text.trim();
}

/** Narrow to the outermost JSON object; ignores any stray prose around it. */
export function extractObject(raw: string): string {
  const text: string = stripFences(raw);
  const start: number = text.indexOf('{');
  const end: number = text.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) {
    throw new VariantParseError('no JSON object found in model output');
  }
  return text.substring(start, end + 1);
}

/**
 * Parse and validate variants.
 *
 * @param raw               model output
 * @param limits            count and length bounds
 * @param originalText      the user's text, used to drop no-op variants
 * @param forbiddenTokens   placeholder-shaped tokens that must not appear
 */
export function parseVariants(
  raw: string,
  limits: ParseLimits,
  originalText: string,
  forbiddenTokens: string[],
): Variant[] {
  const json: string = extractObject(raw);

  let dto: ResponseDto;
  try {
    dto = JSON.parse(json) as ResponseDto;
  } catch (e) {
    throw new VariantParseError('model output is not valid JSON');
  }

  if (dto === null || dto.variants === undefined || !Array.isArray(dto.variants)) {
    throw new VariantParseError('missing "variants" array');
  }

  const out: Variant[] = [];
  const normalizedOriginal: string = originalText.trim();

  for (let i: number = 0; i < dto.variants.length; i++) {
    const item: VariantDto = dto.variants[i];
    if (item === null || typeof item.text !== 'string') {
      continue;
    }

    const text: string = item.text.trim();
    if (text.length === 0) {
      continue;
    }
    if (text.length > limits.maxChars) {
      continue;
    }
    if (text === normalizedOriginal) {
      continue;
    }
    if (containsAny(text, forbiddenTokens)) {
      continue;
    }
    if (containsDuplicate(out, text)) {
      continue;
    }

    let label: string = 'Variant';
    if (typeof item.label === 'string' && item.label.trim().length > 0) {
      label = item.label.trim();
    }

    out.push({ label: label, text: text });
    if (out.length >= limits.maxVariants) {
      break;
    }
  }

  if (out.length === 0) {
    throw new VariantParseError('no usable variants after validation');
  }
  return out;
}

function containsAny(text: string, needles: string[]): boolean {
  for (let i: number = 0; i < needles.length; i++) {
    if (needles[i].length > 0 && text.includes(needles[i])) {
      return true;
    }
  }
  return false;
}

function containsDuplicate(existing: Variant[], candidate: string): boolean {
  for (let i: number = 0; i < existing.length; i++) {
    if (existing[i].text === candidate) {
      return true;
    }
  }
  return false;
}
