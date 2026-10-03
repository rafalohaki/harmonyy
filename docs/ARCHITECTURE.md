# Bridge — Architecture and Implementation

## 1. The capability we bet on

`InputMethodExtensionAbility` (IME Kit). A third-party input method receives, for whichever
application currently owns the focused text field:

- an `InputMethodEngine` to drive the soft keyboard, and
- a `TextEditorProxy` bound to that field, which can read text around the cursor, insert and
  delete text, and move the selection.

That proxy is the whole product. It is the only extension point that lets a component we ship
act **inside every other application** — and it needs no privileged permission and no
system-app identity, unlike the accessibility-service route we evaluated and rejected.

Verified before designing on it: OpenHarmony's IME tool (`hdc shell ime -e <bundle> -f` to
enable, `-s <bundle>` to switch) exists and is **supported since API 20**, so enabling the
keyboard is scriptable rather than a manual Settings journey.

## 2. Layer map

```
┌───────────────────────────────────────────────────────────────────────┐
│ ArkUI keyboard surface (app/entry/src/main/ets/...)                   │
│   Rewrite mode: [Correct] [Plain] [Polite] + variant cards            │
│   Compose mode: token strip (🍽️ 🕐 1) + accept/reject                 │
│   Status line: "offline fallback" · "3 items hidden from the model"   │
└───────────────┬───────────────────────────────────────────────────────┘
                │ calls
┌───────────────▼───────────────────────────────────────────────────────┐
│ core/  — platform-agnostic, ArkTS-compatible TypeScript               │
│                                                                       │
│   RewriteEngine ──► Redactor ──► PromptBuilder ──► LlmTransport (iface)│
│        │                                              │                │
│        │                                              ▼                │
│        │                                     RemoteLlmEngine          │
│        │                                     (OpenAI-compatible)      │
│        │                                              │                │
│        ▼                                              ▼                │
│   VariantParser ◄──────────────────────────── raw model text          │
│        │  on any failure (timeout / 5xx / malformed JSON / refusal)   │
│        ▼                                                              │
│   LocalFallbackEngine  (deterministic rules, no network)              │
└───────────────┬───────────────────────────────────────────────────────┘
                │ injected at the edge, never imported by core
    ┌───────────┴────────────┐
    ▼                        ▼
ArkHttpTransport        FakeTransport (tests)
(@ohos.net.http)        scripted success / failure / garbage
```

The dependency rule is one-directional: `core/` never imports a platform API. The platform
is injected through `LlmTransport`. That single decision buys three things —

1. the engine is **unit-testable today**, with no SDK installed;
2. every AI failure mode is reproducible in a test instead of on stage;
3. the same files move into the ArkTS app unchanged.

## 3. Data flow of one rewrite

1. **Capture.** The keyboard reads the field text (or the selection) through the editor proxy.
2. **Scrub.** `Redactor` replaces e-mails, phone numbers, PESEL, IBAN, card-like digit runs
   and URLs with typed placeholders (`«EMAIL_1»`). It returns the scrubbed text plus a
   restore map and a count.
3. **Prompt.** `PromptBuilder` produces a per-mode instruction (Correct / Plain / Polite) and
   a strict JSON output contract.
4. **Infer.** `RemoteLlmEngine` posts to an OpenAI-compatible endpoint with a timeout and
   bounded retry. Non-2xx, timeout and transport errors are all typed failures.
5. **Parse and validate.** `VariantParser` strips markdown fences, parses JSON, and enforces:
   at most three variants, non-empty trimmed text, bounded length, no leftover placeholders,
   no duplicate of the input.
6. **Restore.** Placeholders are substituted back with the real values.
7. **Render.** The keyboard shows labelled variant cards; a tap replaces the field content.
8. **Degrade.** Any failure in 3–5 produces `LocalFallbackEngine` output, and the UI states
   that it fell back. Silent degradation is treated as a bug.

## 4. Failure behaviour

| Failure | Detection | Behaviour |
| --- | --- | --- |
| No network / DNS | transport error | local fallback, status "offline" |
| Slow endpoint | timeout budget | local fallback, status "timed out" |
| HTTP 4xx/5xx (bad key, quota) | status code | local fallback + explicit reason surfaced |
| Model returns prose, not JSON | parse failure | fence-stripping, then one repair attempt, then fallback |
| Model refuses | refusal marker / empty variants | local fallback |
| Model echoes placeholders | placeholder scan | result rejected, local fallback |
| Field is empty | input validation | buttons disabled, no request made |
| User edits mid-request | request generation counter | stale response discarded, never overwrites newer text |

The generation counter matters: an input method can receive keystrokes while a request is in
flight, and a late response must not clobber what the user just typed.

## 5. Privacy design

The remote path is a disclosure, not a secret. Specifically:

- PII is scrubbed **locally, before the request**; the model sees placeholders only.
- The keyboard displays how many items were hidden, so the user can see the mechanism work.
- The API key is entered on the device and stored in preferences; it is never written to this
  repository, never logged, and never included in a request URL.
- No user text is written to disk or to logs. Only the fallback reason and latency counters
  are recorded, and they contain no content.

## 6. Scope contract

Deliberately excluded, to keep the submission a working narrow solution:

- No privileged permissions, no `hos_system_app`, no ACL profiles.
- No on-device model. The remote engine plus a deterministic fallback is the honest
  architecture; claiming local inference we do not have would be a false claim.
- No sensors, no camera, no distributed features — the emulator cannot demonstrate them.
- Compose mode is second priority. Rewrite mode ships first because it is smaller, entirely
  visible in the demo, and exercises the same engine.

## 7. Go / no-go gate

The single largest technical risk is whether a third-party input method attaches to another
application's text field on the emulator. It is not assumed.

**Gate:** within roughly two hours of the toolchain first working, a skeleton keyboard must
insert a fixed string into a real text field in a real app on the emulator, driven by
`hdc shell ime -e/-s`.

**On failure:** pivot the submission to the notification-intelligence concept
(`NotificationListenerExtensionAbility`, which the organisers' capability matrix confirms is
supported on the DevEco emulator, including the extended-privilege grant). The engine, the
redactor, the parser, the transport abstraction, the tests and most of the documentation
survive the pivot unchanged — which is the reason the engine was built first and built
platform-agnostic.

## 8. Verification plan

| Level | What it proves | How |
| --- | --- | --- |
| Unit | engine logic and every failure mode | `node --test core/test/` |
| Static | ArkTS strictness | `devecocli check lint` |
| Build | HAP is produced | `devecocli build` → `BUILD SUCCESSFUL` |
| Device | installs and launches on the emulator | `devecocli run`, `devecocli log` |
| Behaviour | the keyboard actually rewrites text in a third-party app | `hdc shell ime -e/-s` + `devecocli ui screenshot` capture |

The last row is the one that matters for judging, and it is captured as screenshots from the
emulator so the evidence is reproducible rather than narrated.
