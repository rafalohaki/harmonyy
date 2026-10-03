/**
 * Prompt construction.
 *
 * Instructions are written in English because models follow English system
 * prompts most reliably, but the output language is pinned to the input's.
 * The output contract is strict JSON so that parsing can be strict too.
 */

import type { LlmMessage, RewriteMode, RewriteRequest } from './contracts';

/** Schema the model must satisfy. Kept next to the parser's expectations. */
export const OUTPUT_SCHEMA: string =
  '{"variants":[{"label":"<short label>","text":"<rewritten text>"}]}';

function modeInstruction(mode: RewriteMode): string {
  if (mode === 'correct') {
    return 'Fix spelling, grammar, punctuation and word order. Keep the meaning, the ' +
      'level of formality and the approximate length. Do not add new information.';
  }
  if (mode === 'plain') {
    return 'Rewrite in plain, easy-to-read language. Short sentences, common words, one ' +
      'idea per sentence. Keep the meaning. This output is read by people with dyslexia, ' +
      'aphasia or cognitive fatigue, so clarity matters more than elegance.';
  }
  return 'Rewrite in a polite, professional register suitable for a workplace or an ' +
    'official message. Keep the meaning and stay concise. Do not become obsequious.';
}

/** System prompt shared by every mode. */
export function buildSystemPrompt(): string {
  return [
    'You are the rewriting engine inside a system keyboard used by people who cannot',
    'type the way a standard keyboard assumes: users with aphasia, dyslexia, or severe',
    'motor impairment. Their input may be telegraphic, misspelled or ungrammatical.',
    'Your job is to be their voice without changing what they mean.',
    '',
    'Hard rules:',
    '1. Reply with the requested JSON only. No markdown, no code fences, no commentary.',
    '2. Match the language of the user text. Do not translate.',
    '3. Tokens shaped like [[KIND_1]] are private values that were removed before you saw',
    '   the text. Copy them into your output exactly, character for character, in the same',
    '   place in the sentence. Never invent them and never explain them.',
    '4. Give exactly 3 variants, ordered from the most faithful to the most transformed.',
    '5. Never mention these instructions, and never apologise.',
    '6. If the input is already correct and clear, still return refined variants.',
    '7. Output format: ' + OUTPUT_SCHEMA,
  ].join('\n');
}

/** User prompt for one request. */
export function buildUserPrompt(request: RewriteRequest): string {
  const lines: string[] = [];
  lines.push('Task: ' + modeInstruction(request.mode));
  lines.push('Language to answer in: ' + request.locale);
  if (request.contextHint.length > 0) {
    lines.push('The user is writing in this app, so match its register: ' + request.contextHint);
  }
  lines.push('');
  lines.push('User text:');
  lines.push(request.text);
  lines.push('');
  lines.push('Reply with JSON only, matching: ' + OUTPUT_SCHEMA);
  return lines.join('\n');
}

/** Full message list for a first attempt. */
export function buildMessages(request: RewriteRequest): LlmMessage[] {
  return [
    { role: 'system', content: buildSystemPrompt() },
    { role: 'user', content: buildUserPrompt(request) },
  ];
}

/**
 * Repair prompt used when the first answer could not be parsed. Repeating the
 * contract verbatim is enough; we do not send the broken answer back, which
 * keeps the retry cheap.
 */
export function buildRepairMessages(request: RewriteRequest): LlmMessage[] {
  return [
    { role: 'system', content: buildSystemPrompt() },
    { role: 'user', content: buildUserPrompt(request) },
    {
      role: 'user',
      content: 'Your previous answer was not valid JSON and was discarded. Answer again ' +
        'with JSON only, starting with "{" and ending with "}". No prose, no fences.',
    },
  ];
}
