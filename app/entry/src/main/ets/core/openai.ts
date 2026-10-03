/**
 * OpenAI-compatible wire format, kept pure and testable.
 *
 * Both directions of the HTTP contract live here rather than in the ArkTS
 * transport, for one reason: the transport file cannot be unit-tested without a
 * device, and the request/response shape is exactly the kind of thing that
 * silently breaks against a different provider. Keeping it here means every
 * malformed-response case is covered by a test.
 */

import type { LlmMessage } from './contracts';
import { LlmError } from './contracts';

/** Sampling temperature. Low: this is a rewriting task, not a creative one. */
export const DEFAULT_TEMPERATURE: number = 0.3;

interface ChatMessageDto {
  role: string;
  content: string;
}

interface ChatRequestDto {
  model: string;
  messages: ChatMessageDto[];
  temperature: number;
  stream: boolean;
}

interface ChatChoiceDto {
  message?: ChatMessageDto;
}

interface ChatResponseDto {
  choices?: ChatChoiceDto[];
}

/** Serialise a chat-completions request body. */
export function buildChatRequestBody(
  model: string,
  messages: LlmMessage[],
  temperature: number,
): string {
  const dto: ChatRequestDto = {
    model: model,
    messages: toDto(messages),
    temperature: temperature,
    stream: false,
  };
  return JSON.stringify(dto);
}

/**
 * Extract the assistant message from a chat-completions response body.
 * Every rejection path raises a typed transport error so the engine falls back
 * deliberately instead of showing a half-parsed answer.
 */
export function parseChatCompletion(body: string): string {
  let dto: ChatResponseDto;
  try {
    dto = JSON.parse(body) as ChatResponseDto;
  } catch (e) {
    throw new LlmError('transport', 'response body was not JSON', 0);
  }

  if (dto === null || dto.choices === undefined || !Array.isArray(dto.choices)) {
    throw new LlmError('transport', 'response contained no choices', 0);
  }
  if (dto.choices.length === 0) {
    throw new LlmError('transport', 'response contained an empty choices array', 0);
  }

  const message: ChatMessageDto | undefined = dto.choices[0].message;
  if (message === undefined || message === null) {
    throw new LlmError('transport', 'response contained no message', 0);
  }
  if (typeof message.content !== 'string') {
    throw new LlmError('transport', 'response contained no message content', 0);
  }
  if (message.content.length === 0) {
    throw new LlmError('transport', 'response contained empty message content', 0);
  }
  return message.content;
}

function toDto(messages: LlmMessage[]): ChatMessageDto[] {
  const out: ChatMessageDto[] = [];
  for (let i: number = 0; i < messages.length; i++) {
    out.push({ role: messages[i].role, content: messages[i].content });
  }
  return out;
}
