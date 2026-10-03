/**
 * Core contracts for the Bridge rewrite engine.
 *
 * This file is deliberately platform-agnostic and ArkTS-compatible:
 * no `any`, no enums, no destructuring, no platform imports.
 * The network lives behind LlmTransport and is injected at the edge.
 */

/** What the user asked the keyboard to do with the text. */
export type RewriteMode = 'correct' | 'plain' | 'polite';

/** All modes, for UI iteration and validation. */
export const REWRITE_MODES: RewriteMode[] = ['correct', 'plain', 'polite'];

/** Human-facing label for a mode. Kept here so UI and tests agree. */
export function modeLabel(mode: RewriteMode): string {
  if (mode === 'correct') {
    return 'Correct';
  }
  if (mode === 'plain') {
    return 'Plain';
  }
  return 'Polite';
}

/** One rewrite job. */
export interface RewriteRequest {
  /** Raw text from the focused editor. */
  text: string;
  mode: RewriteMode;
  /** Best-effort hint about the hosting app, e.g. "Messages". May be empty. */
  contextHint: string;
  /** BCP-47-ish tag of the text language, e.g. "pl-PL". */
  locale: string;
}

/** One candidate rewrite. */
export interface Variant {
  label: string;
  text: string;
}

/** Where the answer actually came from. */
export type RewriteSource = 'remote' | 'local';

/** Result handed to the keyboard surface. */
export interface RewriteOutcome {
  variants: Variant[];
  source: RewriteSource;
  /** Empty when source is 'remote'. Otherwise a short, user-showable reason. */
  fallbackReason: string;
  /** How many PII items were withheld from the model. */
  redactedCount: number;
  /** Wall-clock duration of the remote attempt, 0 for pure fallback. */
  latencyMs: number;
}

/** A chat message in the OpenAI-compatible sense. */
export interface LlmMessage {
  role: string;
  content: string;
}

/**
 * The only way core reaches a model. Implemented by ArkHttpTransport in the app
 * and by scripted fakes in tests.
 *
 * Implementations must reject with LlmError on failure and never return null.
 */
export interface LlmTransport {
  complete(messages: LlmMessage[], timeoutMs: number): Promise<string>;
}

/** Why a remote attempt failed. Kept coarse so the UI can explain it briefly. */
export type LlmFailureKind = 'timeout' | 'http' | 'transport' | 'auth';

/** Typed transport failure. */
export class LlmError extends Error {
  kind: LlmFailureKind;
  status: number;

  constructor(kind: LlmFailureKind, message: string, status: number) {
    super(message);
    this.name = 'LlmError';
    this.kind = kind;
    this.status = status;
  }
}

/** Raised when model output cannot be trusted as a set of variants. */
export class VariantParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'VariantParseError';
  }
}

/** Placeholder substitution record produced by the Redactor. */
export interface PlaceholderEntry {
  placeholder: string;
  original: string;
  kind: string;
}
