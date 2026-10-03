/**
 * RewriteEngine — the orchestration the keyboard surface talks to.
 *
 * Flow: scrub -> prompt -> infer -> validate -> restore, with a deterministic
 * offline engine as the floor. The engine never throws for an expected failure;
 * it returns an outcome that says which source answered and why.
 */

import type {
  LlmMessage,
  LlmTransport,
  PlaceholderEntry,
  RewriteMode,
  RewriteOutcome,
  RewriteRequest,
  Variant,
} from './contracts.ts';
import { LlmError, VariantParseError } from './contracts.ts';
import type { ParseLimits } from './parse.ts';
import { DEFAULT_LIMITS, parseVariants } from './parse.ts';
import { buildMessages, buildRepairMessages } from './prompt.ts';
import { Redactor, DEFAULT_RULES } from './redact.ts';
import { localVariants } from './fallback.ts';

/** Tunables, injected so tests can drive every branch. */
export interface EngineOptions {
  timeoutMs: number;
  maxAttempts: number;
  limits: ParseLimits;
  redactionEnabled: boolean;
}

export const DEFAULT_OPTIONS: EngineOptions = {
  timeoutMs: 12000,
  maxAttempts: 2,
  limits: DEFAULT_LIMITS,
  redactionEnabled: true,
};

/** Clock indirection so latency can be asserted in tests. */
export type NowFn = () => number;

export class RewriteEngine {
  private transport: LlmTransport;
  private options: EngineOptions;
  private redactor: Redactor;
  private now: NowFn;

  constructor(transport: LlmTransport, options: EngineOptions, now: NowFn) {
    this.transport = transport;
    this.options = options;
    this.redactor = new Redactor(DEFAULT_RULES);
    this.now = now;
  }

  /**
   * Produce variants for one request. Guaranteed to resolve with at least one
   * usable variant unless the input itself is empty, which the caller must
   * prevent anyway.
   */
  async rewrite(request: RewriteRequest): Promise<RewriteOutcome> {
    const trimmed: string = request.text.trim();

    if (trimmed.length === 0) {
      return {
        variants: [],
        source: 'local',
        fallbackReason: 'Nothing to rewrite yet.',
        redactedCount: 0,
        latencyMs: 0,
      };
    }

    let redactedCount: number = 0;
    let map: PlaceholderEntry[] = [];
    let outgoing: string = request.text;

    if (this.options.redactionEnabled) {
      const redaction = this.redactor.redact(request.text);
      outgoing = redaction.text;
      map = redaction.map;
      redactedCount = redaction.count;
    }

    const sanitized: RewriteRequest = {
      text: outgoing,
      mode: request.mode,
      contextHint: request.contextHint,
      locale: request.locale,
    };

    const startedAt: number = this.now();
    let lastReason: string = '';
    let latencyMs: number = 0;

    for (let attempt: number = 1; attempt <= this.options.maxAttempts; attempt++) {
      const messages: LlmMessage[] = attempt === 1
        ? buildMessages(sanitized)
        : buildRepairMessages(sanitized);

      let raw: string = '';
      try {
        raw = await this.transport.complete(messages, this.options.timeoutMs);
      } catch (e) {
        latencyMs = this.now() - startedAt;
        lastReason = describeLlmFailure(e as Error);
        break;
      }

      latencyMs = this.now() - startedAt;

      try {
        const restored: Variant[] = this.validateAndRestore(raw, map, request.text);
        return {
          variants: restored,
          source: 'remote',
          fallbackReason: '',
          redactedCount: redactedCount,
          latencyMs: latencyMs,
        };
      } catch (e) {
        lastReason = describeParseFailure(e as Error);
        // Loop again: the repair prompt is strictly more explicit.
      }
    }

    const fallbackReason: string = lastReason.length > 0
      ? lastReason
      : 'The model did not return a usable answer.';

    return {
      variants: localVariants(request),
      source: 'local',
      fallbackReason: fallbackReason,
      redactedCount: redactedCount,
      latencyMs: latencyMs,
    };
  }

  /** Validate model output against the placeholder contract, then restore. */
  private validateAndRestore(
    raw: string,
    map: PlaceholderEntry[],
    originalText: string,
  ): Variant[] {
    const unknown: string[] = this.redactor.unknownPlaceholders(raw, map);
    if (unknown.length > 0) {
      throw new VariantParseError('model invented placeholder tokens');
    }

    const variants: Variant[] = parseVariants(raw, this.options.limits, originalText, []);

    const out: Variant[] = [];
    for (let i: number = 0; i < variants.length; i++) {
      const variant: Variant = variants[i];
      const missing: string[] = this.redactor.missingPlaceholders(variant.text, map);
      if (missing.length > 0) {
        throw new VariantParseError('model dropped private placeholders');
      }
      out.push({
        label: variant.label,
        text: this.redactor.restore(variant.text, map),
      });
    }
    return out;
  }
}

/** Map a transport failure to something short enough to show on a keyboard. */
export function describeLlmFailure(error: Error): string {
  if (error instanceof LlmError) {
    if (error.kind === 'timeout') {
      return 'The model timed out.';
    }
    if (error.kind === 'auth') {
      return 'The API key was rejected.';
    }
    if (error.kind === 'http') {
      return 'The model service returned HTTP ' + error.status + '.';
    }
    return 'The model service could not be reached.';
  }
  return 'The model service could not be reached.';
}

function describeParseFailure(error: Error): string {
  if (error instanceof VariantParseError) {
    return 'The model answer was unusable.';
  }
  return 'The model answer was unusable.';
}

/** Convenience: a mode is valid when it is one of the three known modes. */
export function isRewriteMode(value: string): boolean {
  const modes: RewriteMode[] = ['correct', 'plain', 'polite'];
  return modes.includes(value as RewriteMode);
}
