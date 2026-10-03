/**
 * ArkHttpTransport — the platform edge of the rewrite engine.
 *
 * This is the only file that knows how to talk to the network. It implements the
 * LlmTransport interface from core/ and translates every platform failure into a
 * typed LlmError, because the engine's fallback decisions depend on that
 * distinction: a timeout and a rejected API key are different problems and the
 * user is told which one happened.
 *
 * Grounded against OpenHarmony's network documentation:
 *   - import { http } from '@kit.NetworkKit'
 *   - http.createHttp() -> HttpRequest; destroy() must be called to avoid leaks
 *   - HttpRequestOptions: method, header, extraData, expectDataType,
 *     connectTimeout, readTimeout
 *   - HttpResponse: responseCode, result
 *   - error codes: 2300028 timeout, 2300006 DNS, 2300007 connect,
 *     2300003 invalid URL, 2300052 empty reply
 */

import { http } from '@kit.NetworkKit';
import type { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import type { LlmFailureKind, LlmMessage, LlmTransport } from '../core/contracts';
import { LlmError } from '../core/contracts';
import { TAG, DOMAIN } from '../common/Log';

/** Error codes taken from the HttpRequest error-code table. */
const ERR_TIMEOUT: number = 2300028;
const ERR_RESOLVE_HOST: number = 2300006;
const ERR_CONNECT: number = 2300007;
const ERR_INVALID_URL: number = 2300003;
const ERR_EMPTY_REPLY: number = 2300052;

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

function classify(code: number): LlmFailureKind {
  if (code === ERR_TIMEOUT) {
    return 'timeout';
  }
  return 'transport';
}

/** Error codes that mean "the request never reached a usable server". */
function isConnectivityCode(code: number): boolean {
  return code === ERR_RESOLVE_HOST || code === ERR_CONNECT
    || code === ERR_INVALID_URL || code === ERR_EMPTY_REPLY;
}

export class ArkHttpTransport implements LlmTransport {
  private baseUrl: string;
  private model: string;
  private apiKey: string;

  constructor(baseUrl: string, model: string, apiKey: string) {
    this.baseUrl = baseUrl;
    this.model = model;
    this.apiKey = apiKey;
  }

  /** Normalise the configured base URL into a chat-completions endpoint. */
  chatUrl(): string {
    let base: string = this.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.endsWith('/chat/completions')) {
      return base;
    }
    return base + '/chat/completions';
  }

  async complete(messages: LlmMessage[], timeoutMs: number): Promise<string> {
    if (this.apiKey.trim().length === 0) {
      throw new LlmError('auth', 'no API key configured', 0);
    }

    const payload: ChatRequestDto = {
      model: this.model,
      messages: this.toDto(messages),
      temperature: 0.3,
      stream: false
    };

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + this.apiKey
    };

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: JSON.stringify(payload),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs
    };

    const url: string = this.chatUrl();
    const request: http.HttpRequest = http.createHttp();

    try {
      const response: http.HttpResponse = await request.request(url, options);
      const status: number = response.responseCode;
      const body: string = typeof response.result === 'string' ? response.result : '';

      if (status < 200 || status >= 300) {
        const kind: LlmFailureKind = (status === 401 || status === 403) ? 'auth' : 'http';
        // The body is truncated: an error page can be long, and the engine only
        // needs enough to report a reason.
        throw new LlmError(kind, 'HTTP ' + status + ': ' + body.substring(0, 200), status);
      }

      return this.extractContent(body);
    } catch (err) {
      if (err instanceof LlmError) {
        throw err;
      }
      const error: BusinessError = err as BusinessError;
      if (isConnectivityCode(error.code)) {
        hilog.warn(DOMAIN, TAG, 'transport failure %{public}d', error.code);
      }
      throw new LlmError(classify(error.code), error.message, 0);
    } finally {
      // Documented requirement: release the request object or leak memory.
      request.destroy();
    }
  }

  /** Pull the assistant message out of an OpenAI-compatible response. */
  private extractContent(body: string): string {
    let dto: ChatResponseDto;
    try {
      dto = JSON.parse(body) as ChatResponseDto;
    } catch (err) {
      throw new LlmError('transport', 'response body was not JSON', 0);
    }

    const choices: ChatChoiceDto[] | undefined = dto.choices;
    if (choices === undefined || choices.length === 0) {
      throw new LlmError('transport', 'response contained no choices', 0);
    }

    const message: ChatMessageDto | undefined = choices[0].message;
    if (message === undefined || typeof message.content !== 'string'
      || message.content.length === 0) {
      throw new LlmError('transport', 'response contained no message content', 0);
    }
    return message.content;
  }

  private toDto(messages: LlmMessage[]): ChatMessageDto[] {
    const out: ChatMessageDto[] = [];
    for (let i: number = 0; i < messages.length; i++) {
      out.push({ role: messages[i].role, content: messages[i].content });
    }
    return out;
  }
}
