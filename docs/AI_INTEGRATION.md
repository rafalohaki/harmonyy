# AI Integration

Required because Bridge ships an AI feature. This documents the model, the
inference flow, how data is handled, what the limits are, how the output is
validated, and what the privacy position actually is.

Companion documents: [`AI_WORKFLOW.md`](../AI_WORKFLOW.md) (how the project was
built with AI tooling) and [`ARCHITECTURE.md`](ARCHITECTURE.md) (component map).

---

## 1. Model and service

| Item | Value |
| --- | --- |
| Provider | Any **OpenAI-compatible** `/chat/completions` endpoint |
| Configuration | Base URL, model name and API key, entered on the device |
| Defaults | `https://api.openai.com/v1`, `gpt-4o-mini` |
| Protocol | HTTPS, JSON request and response |
| Runs where | **Remote.** There is no on-device model in this submission, and we do not claim one |
| Timeout | 12 seconds per attempt (`DEFAULT_OPTIONS.timeoutMs`) |
| Attempts | 2 maximum, the second being an explicit JSON-repair prompt |

The provider is deliberately not hard-coded. The engine talks to an interface
(`LlmTransport`) and the concrete HTTP implementation is injected by the app, so
supporting a different vendor is a one-file change in the app layer and no change
in the tested core.

## 2. Inference flow

```
field text
   │
   ├─ 1. Local PII scrub          (core/src/redact.ts)
   │      e-mail, URL, PL IBAN, card, PESEL, phone
   │      → replaced with [[KIND_n]] placeholders
   │
   ├─ 2. Prompt build             (core/src/prompt.ts)
   │      system prompt: assistive-writing role, language pinning,
   │                     "copy placeholders verbatim", strict JSON contract
   │      user prompt:   mode instruction + app register hint + scrubbed text
   │
   ├─ 3. Remote call              (app: ArkHttpTransport, @ohos.net.http)
   │
   ├─ 4. Validation               (core/src/parse.ts)
   │      fences stripped, JSON parsed, structure checked,
   │      ≤3 variants, non-empty, length-bounded, deduplicated,
   │      no invented placeholders, no dropped placeholders
   │
   ├─ 5. Local restore            (core/src/redact.ts)
   │      placeholders → real values
   │
   └─ 6. Render 3 labelled variants; a tap replaces the field content
          │
          └─ any failure in 2–5 → LocalFallbackEngine + a visible reason
```

## 3. Data handling

| Question | Answer |
| --- | --- |
| What leaves the device? | The scrubbed text, the mode, a locale tag, and a best-effort app-name hint |
| What does **not** leave? | The detected identifiers (e-mail, phone, PESEL, IBAN, card, URL), the API key, and any log content |
| Is content written to disk? | No. Only the fallback reason and latency counters are kept, and they contain no user text |
| Is content logged? | No. Log statements record lengths and error codes, never text |
| Where is the key stored? | Device preferences via `@kit.ArkData`, entered in the app's settings screen |
| Is the key in this repository? | No. `.gitignore` excludes `.env`, `*.local`, `secrets/` and signing material |
| Retention by the provider | Governed by the provider the user configures. This is disclosed in the UI and the README rather than glossed over |

## 4. Privacy position, stated honestly

Two claims are worth separating, because conflating them would be dishonest:

1. **What we do claim.** Structured personal identifiers are removed locally,
   before the request, and restored afterwards. The keyboard shows how many items
   were hidden, so the user can see the mechanism working rather than trust it.
2. **What we do not claim.** This is not an on-device model, and regex scrubbing
   is not a guarantee. It catches structured identifiers; it does **not** catch
   names, addresses or other identifiers embedded in free prose. Sensitive
   content still reaches a third-party service.

That is why the offline engine exists and why the UI states which source answered.
A user who cannot accept a remote round trip can still use the product, with a
smaller feature set and an explicit "offline" label.

## 5. Limitations

- **Language.** The offline engine's filler list and imperative table are Polish.
  The remote path is language-agnostic but the prompts pin the output language to
  the input's.
- **Scrubber coverage.** Structured identifiers only. Free-text names and
  addresses pass through.
- **Placeholder fragility.** The model is instructed to copy `[[KIND_n]]` tokens
  verbatim. If it does not, the response is rejected rather than restored
  partially — a deliberate choice, because a partially restored answer could
  silently swap or lose a value.
- **Quality.** Assisted rewriting of telegraphic input is inherently lossy; the
  three-variant design exists so the user chooses rather than accepts.
- **No streaming.** A single request/response round trip keeps the IME's
  interaction model simple; perceived latency is therefore bounded by the timeout.
- **No personalisation.** The engine does not learn the user's style. The app-name
  hint is the only contextual signal.

## 6. Validation approach

The claim "it behaves well when the model misbehaves" is backed by tests, not by
inspection. `core/test/engine.test.ts` drives the engine with a scripted transport:

| Scenario | Injected failure | Expected behaviour | Test |
| --- | --- | --- | --- |
| Network | transport error | local fallback, reason shown | covered by timeout/auth cases |
| Timeout | `LlmError('timeout')` | local fallback, not retried | yes |
| Server error | `LlmError('http', 503)` | fallback naming the status | yes |
| Bad key | `LlmError('auth', 401)` | fallback stating the key was rejected | yes |
| Prose instead of JSON | non-JSON text | repair attempt, then success | yes |
| Repeated garbage | two bad answers | fallback after bounded attempts | yes |
| Invented placeholder | `[[SECRET_9]]` | response rejected | yes |
| Dropped placeholder | answer omits `[[EMAIL_1]]` | response rejected | yes |
| Empty input | whitespace only | no network call at all | yes |
| Privacy | real e-mail in input | placeholder in the outgoing request, real value in the result | yes |

Run them with `node --test core/test/` or `scripts/dev-loop.sh tests`. The suite
requires only Node.js 22+ and passes with no SDK installed.

## 7. Review of AI-generated output during development

Model output was never trusted as a source of truth about the platform. Every
platform-specific claim in this repository — the extension declaration, the panel
API, the text-insertion API, the CLI path for enabling an input method — was
checked against OpenHarmony documentation or the official IME sample before it was
written into code. Where a claim could not be verified, it is marked as
unverified in `AI_WORKFLOW.md` rather than presented as fact.

## 8. Error handling summary

The engine never throws for an expected failure. It returns a `RewriteOutcome`
with `source: 'remote' | 'local'` and a `fallbackReason` that the keyboard renders.
Silent degradation is treated as a bug: if the answer came from the offline
engine, the UI says so.

---

## 9. Offline-only mode

A switch on the settings screen makes the rewrite never contact the network **at all**. It is for
the user who cannot accept sending even scrubbed text to a third party, and it is the difference
between a privacy feature and a privacy claim.

How it is enforced, rather than merely intended:

- `EngineOptions.forceOffline` makes `RewriteEngine.rewrite` return the local result **before the
  transport is reached**, so no request can be constructed. A policy that lives in an `if` around
  the call site could be refactored away by accident; this cannot.
- Because nothing leaves the device, nothing needs withholding, so the outcome reports
  `redactedCount: 0` rather than a count that would imply a transmission happened.
- Four tests assert the promise directly, on the transport never being called — not on the outcome
  merely looking local, which it would in either case.

Verified on the emulator with the endpoint and the API key both configured: asking for a rewrite
produced `offline: Offline-only mode is on.` and a local result, with no request made
(`docs/evidence/09-offline-only.png`).

In this mode the data-handling table in section 3 is simpler than it looks: the "what leaves the
device" row becomes *nothing*, and the redaction machinery is bypassed because it has nothing to
protect.
