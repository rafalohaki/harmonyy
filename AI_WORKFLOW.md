# AI Workflow

This file is a mandatory deliverable. It records every AI model, agent, MCP server and Agent
Skill used to build Bridge, the instructions that shaped the work, how the output was
reviewed, and what went wrong. It is updated as the build progresses.

No API keys, credentials, personal data or private endpoints appear in this file.

---

## 1. Tools used

### 1.1 Coding agent

| Tool | Version / model | Role |
| --- | --- | --- |
| DeepSeek Harness (DSH) | session-driven coding agent | Whole development workflow: reconnaissance, architecture, implementation, tests, documentation |
| `deepseek-v4.1-flash` | model used for the reconnaissance and design phase | Reading documentation, comparing approaches, drafting the architecture |
| `deepseek-flash` | model used from the implementation phase onward | Writing and testing the engine and the ArkTS app |

### 1.2 MCP servers

| Server | Used for | Concrete use in this project |
| --- | --- | --- |
| `deepwiki` | Repository-grounded Q&A | Asked whether a **non-system** third-party app can provide an `AccessibilityExtensionAbility` on OpenHarmony, and what permissions/signing it needs. Answer: it requires `ohos.permission.ACCESSIBILITY_EXTENSION_ABILITY` (`system_basic`, ACL) and many of the `AccessibilityExtensionContext` APIs were deprecated around OpenHarmony 5.0.0.35. **This answer directly caused us to reject an accessibility-service route and choose the IME route instead.** |
| `context7` | Library/framework documentation | Available; not required for this project because OpenHarmony documentation is not indexed there. Recorded for completeness. |

### 1.3 Agent Skills

The challenge repository (`onirodeveloper/hackyeah2026-challenge`) ships nine agent skills.
They were **read as reference material** for this project:

| Skill | How it influenced the work |
| --- | --- |
| `ohos-system-app-dev` | Established that a system app can be signed **offline** with the Full SDK development certificate chain (`hap-sign-tool.jar`, `OpenHarmony.p12`, `UnsgnedReleasedProfileTemplate.json`) without a Huawei account. We then decided **not** to need it, and documented why. |
| `ohos-app-dev`, `ohos-app-scaffold` | Command surface and inner development loop: lint → build → sign → install → launch → observe, all through `devecocli` |
| `hmos-arkts-knowledge-retriever` | Grounded ArkTS/API reference material bundled with the skill |

### 1.4 Non-AI tooling consulted

- `devecocli` (DevEco CLI) 1.3.4 — build, run, device, emulator, log, lint, UI automation
- OpenHarmony documentation from the `openharmony/docs` repository — used to verify the
  **IME tool exists and is supported since API 20** (`hdc shell ime -e/-s`) before betting the
  architecture on it
- The challenge repository's own `FAQ.md`, `README.md` and workshop slide deck

---

## 2. Instructions that shaped the work

The user's governing constraints, given as direct instructions:

1. "**Must win, but don't overreach — I have no physical device**, only the emulator."
2. "**1–2 people, under 24 hours.**"
3. "LLM: **remote, via API** (OpenAI-compatible)."

These constraints drove three architecture decisions:

- **Reject every idea that depends on unavailable hardware** (camera, sensors, Bluetooth,
  distributed multi-device). The emulator capability matrix was treated as a hard filter.
- **Reject the privileged accessibility-service route**, because system-app signing and a
  partially deprecated API set is a schedule risk that a sub-24-hour build cannot absorb.
- **Choose a capability that the command line can drive end to end**, so that the demo and
  the tests are scripted rather than clicked, which also serves the reproducibility criterion.

The decisive external instruction was the organisers' own scoping advice, quoted from their
workshop deck:

> Pick one capability and make it work end to end. Breadth reads as unfinished.
> Build the install path early. First `.hap` on a device or emulator within the first few hours.
> Record the demo before you are out of time, not after.
> Say plainly what is real and what is fake.
> Write the README as you go.

Our response to it: one platform capability (`InputMethodExtensionAbility`), two modes on top
of one engine, a deterministic offline fallback so a failed model response cannot break the
demo, and a documented **go/no-go gate** that pivots the whole submission to a notification
agent if the keyboard skeleton is not inserting text within two hours of the toolchain
coming up.

---

## 3. Workflow

1. **Reconnaissance (agent-driven).** Cloned the challenge repository, read `FAQ.md`,
   `README.md`, `hackathon_challenge.md`, the emulator capability matrix and the nine bundled
   Agent Skills. Extracted the organisers' workshop slide deck (image-only PDF) and read the
   evaluation and scoping slides to recover judging guidance that was not in the written
   statement.
2. **Feasibility verification before designing.** Used `deepwiki` to test the privileged
   accessibility route, and fetched OpenHarmony's IME documentation to confirm the
   `hdc shell ime -e/-s` tool exists and is available from API 20. Both facts were confirmed
   *before* the architecture depended on them.
3. **Toolchain probing.** Installed `devecocli` locally and discovered, by running it, that it
   requires either DevEco Studio or Command Line Tools on disk. This turned a guess into a
   known blocker and made the Huawei download the project's critical path.
4. **Engine-first implementation.** The engine is written in strict, ArkTS-compatible
   TypeScript with the network behind an injected `LlmTransport` interface. That makes it
   testable under plain Node immediately, with no SDK present, and portable into the ArkTS
   application unchanged.
5. **Tests as the review mechanism.** Every AI-failure mode is covered by a unit test with a
   fake transport: HTTP 500, timeout, malformed JSON, model refusal, empty output, and a
   response that tries to leak the redaction placeholders.

---

## 4. How generated output is reviewed and validated

- **Documentation claims are checked at the source.** The IME command syntax, the API level
  it appeared in, and the emulator's capability limits were read from OpenHarmony and
  organiser sources rather than recalled from model memory.
- **Model output is treated as untrusted input at runtime.** The parser validates structure,
  variant count, length and emptiness, strips markdown fences, rejects outputs that still
  contain internal placeholders, and falls back to the local engine on any violation.
- **Behaviour is proven by tests, not by inspection.** `node --test core/test/` must pass.
- **Runtime claims require runtime evidence**, on the four-gate standard borrowed from the
  organiser's system-app skill: build succeeds, installs, launches, and the intended
  behaviour is observed on the emulator. A successful build alone is never reported as
  success.

---

## 5. Known limitations and unsuccessful approaches

- **Rejected: accessibility-service "label repair" layer.** Highest novelty of everything we
  considered, killed by verified evidence: it needs `system_basic` + ACL signing, and many
  `AccessibilityExtensionContext` query/inject APIs were deprecated or removed. Not a
  sub-24-hour bet.
- **Rejected: on-device GUI agent.** Attractive and trendy, but small local models do not
  ground UI reliably, and it inherits the same privileged-permission risk.
- **Rejected: any spatial concept.** With no camera, no real sensors and no distributed
  device support in the emulator, a spatial submission would have been mostly simulated,
  which the organisers explicitly warn reads as unfinished.
- **Remaining risk:** the input method must attach to a third-party text field on the
  emulator. This is not assumed — it is the first thing we test once the SDK is installed,
  and the pivot is pre-planned if it fails.
- **Remote LLM trade-off:** the rewrite path sends scrubbed text to a third-party service.
  This is disclosed in the UI, in the README and in `docs/AI_INTEGRATION.md`. We do not claim
  on-device inference for that path. The offline fallback exists so the product degrades
  honestly rather than silently failing.

---

## 6. Work log

### Session 1 — reconnaissance, architecture, engine, app skeleton

**Reconnaissance.** Cloned the organisers' repository and read `FAQ.md`, `README.md`, the
emulator capability matrix, the nine bundled Agent Skills and the workshop slide deck
(image-only PDF, recovered by extracting and reading its slides). Extracted the judging
guidance that is not in the written statement, most importantly the scoping advice quoted in
section 2.

**Feasibility checks before designing.** Two platform questions decided the architecture, and
both were answered from primary sources rather than assumption:

1. *Can a third-party app provide an `AccessibilityExtensionAbility`?* Answered via the
   `deepwiki` MCP server against `openharmony/docs`: it needs
   `ohos.permission.ACCESSIBILITY_EXTENSION_ABILITY` (`system_basic`, ACL) and many
   `AccessibilityExtensionContext` query/inject APIs were deprecated around OpenHarmony
   5.0.0.35. This eliminated the highest-novelty idea we had.
2. *Can an input method be enabled and switched from the command line?* Answered from
   OpenHarmony's IME documentation: `hdc shell ime -e/-s`, **supported since API 20**. This is
   what made the chosen route reproducible and scriptable, and it is why the route was chosen.

**Toolchain probing.** Ran `devecocli` to discover, rather than assume, what it needs. It is a
wrapper that requires DevEco Studio or Command Line Tools on disk, which turned the Huawei
download into the project's critical path — a fact worth knowing on hour one rather than hour
ten.

**Implementation.** The engine was written first and written platform-agnostic, so that 58
unit tests and a strict `tsc --noEmit` pass could run before an SDK existed. The ArkTS
skeleton was then grounded on OpenHarmony's IME documentation and the official
`KikaInputMethod` sample, whose `module.json5` and `input_method_config.json` were fetched and
followed exactly rather than reconstructed from memory.

**Bugs that testing caught**, none of which would have been visible by reading the code:

1. A nine-digit national phone number did not match the redaction rule at all, because the
   country-prefix group was mandatory, and a leading `\b` cannot match between a space and a
   `+`, which left a dangling `+48` fragment in the scrubbed text. Fixed with an optional
   prefix group plus an explicit boundary policy that replaces the non-portable lookbehind,
   and both cases are now regression tests.
2. A test asserted `Proszę wysłać` after a comma, but Polish lowercases after a comma, so the
   assertion was wrong rather than the code. The test was corrected and the reason recorded in
   a comment.

**A bug caught by grounding rather than by testing.** The first version of the text-replacement
path read and deleted the field content with `getBackwardSync` / `deleteBackwardSync`, which is
what the English names suggest. The English reference describes those as operating "after the
cursor", which contradicts their own names, so the point was checked against two independent
sources: the Chinese reference (which is the source of the translation) says the same thing, and
the official IME sample maps `KEYCODE_DEL` — the backspace key — to `deleteForward(1)`. The
naming is genuinely inverted. Left unfixed, the rewrite would have **appended** the model's
answer to the user's text instead of replacing it, in every mode, which is the one behaviour a
demo cannot survive and a unit test cannot catch, because the inverted calls are platform APIs
that only exist on a device. Corrected to `getForwardSync` / `deleteForwardSync`, with the
evidence recorded in a comment next to the code so nobody re-introduces it.

**Portability problems found and fixed before the first build:**

- Node's ESM resolver requires `./contracts.ts`; the ArkTS toolchain expects `./contracts`.
  Rather than compromise either side, `scripts/sync-core.sh` rewrites relative import
  specifiers during the copy and then **verifies** that none remain.
- `gitignore` does not support trailing comments on a pattern line. The first `.gitignore`
  silently matched nothing, and a partially downloaded multi-gigabyte installer briefly
  entered the staging area. Fixed, and installer extensions are now excluded explicitly.

**A tool built for this situation.** Because the SDK is the only real compiler and a missing
resource costs a full build cycle, `scripts/check-refs.mjs` statically verifies that every
relative import, every `$string:`/`$media:`/`$color:`/`$profile:` reference, every declared
page and every `srcEntry` resolves. It is not a substitute for `devecocli build`; it removes
the cheap failures from the expensive ones.

**Untested code was moved to where it could be tested.** The OpenAI-compatible request and
response shapes initially lived in the ArkTS transport file, which cannot be unit-tested
without a device. That is exactly where a silent break against a different provider would
hide, so both directions were moved into `core/src/openai.ts` as pure functions and covered by
14 tests enumerating every malformed response shape (non-JSON, missing choices, empty choices,
missing message, null message, non-string content, empty content, and extra fields). The
transport now contains no protocol logic at all.

**Two compile errors found by reading the SDK's own type declarations.** Once the Full
OpenHarmony SDK had been downloaded and extracted, its `ets/api/**.d.ts` files became the
authoritative API reference for the exact version being targeted — better than the
documentation, and far better than recollection. Every platform call in the input method was
checked against them, which caught two defects that no amount of further review-by-eye would
have found, because both come from a plausible-looking official example:

1. **`inputMethodAbility` does not exist anywhere in the API 23 declarations.** It is used
   throughout OpenHarmony's own IME guide, but it is not exported by `@kit.IMEKit`, not
   declared in `@ohos.inputMethodEngine`, and appears nowhere else in the SDK. The panel and
   event APIs are methods of the `InputMethodAbility` *interface*, obtained with
   `inputMethodEngine.getInputMethodAbility()`. The code as originally written would not have
   compiled, and the error message would have pointed at an import rather than at the mental
   model that was wrong.
2. **`off('inputStop', callback)` requires its callback**, while `off('inputStart', callback?)`
   does not. The original code called `off('inputStop')` with no argument, which is a type
   error, and the fix is not just a signature change: the callback reference has to be retained
   for the lifetime of the listener.

A third, smaller defect came out of the same pass: `UIContext.getHostContext()` is declared as
returning `Context | undefined`, so the settings screen now handles an absent context and says
so, rather than dereferencing it.

**A tool built so the AI could be judged before the device existed.** `scripts/try-engine.mjs`
drives the shipped engine from the terminal. With `--mock` it starts a local OpenAI-shaped
server, so the whole HTTP path — request serialisation, redaction, placeholder restoration,
strict parsing — is exercised with no credentials and no network; without the flag it calls the
configured real endpoint. This mattered because the engine's usefulness depends on how a real
model answers our prompt, and discovering a bad prompt only after a working `.hap` exists is the
most expensive possible order of operations. It also demonstrated the degradation path on
demand, which is the branch the keyboard takes when the network drops.

**Milestone framing.** The ArkTS skeleton deliberately contains no engine wiring at first.
The first milestone is proving that a third-party input method can attach to another
application's text field and write into it, because every other claim depends on that. The
mode buttons state plainly that they are not the model yet.

### Session 2 — the toolchain lands, and the code compiles

**What the compiler caught that reading had not.** The project built successfully on the first
attempt after the scaffold was in place, but not before ArkTS reported two things:

1. `PanelInfo`, `PanelType` and `PanelFlag` are declared **twice** in the SDK — once in
   `@ohos.inputMethod.Panel` and once inside the `inputMethodEngine` namespace — and the two are
   not interchangeable. `createPanel` accepts only the engine's, and the two disagree on enum
   spelling: the engine has `FLG_FIXED`, the Panel module has `FLAG_FIXED`. The error was a type
   mismatch, not a missing symbol, which is why reading the declaration file had not revealed
   it.
2. The HTTP call needs `ohos.permission.INTERNET`, which ArkTS reports as a **warning at the
   call site rather than an error**. Left alone it would have surfaced as a runtime network
   failure with no obvious cause. It is now declared with a user-facing reason string.

**The scaffold was the missing piece, and it corrected three assumptions.** Running
`devecocli create` to obtain a reference project revealed that our hand-written configuration
was wrong in ways that would each have produced a confusing build error: there was no
`AppScope/app.json5` at all (the application-level manifest), no `hvigor/hvigor-config.json5`,
and the runtime is `HarmonyOS` with version labels like `6.1.1(24)` rather than `OpenHarmony`
with numeric API levels. The home action is also spelled `ohos.want.action.home`, not the older
`action.system.home`. The scaffold was then grafted in and committed, so a clean checkout needs
no scaffolding step.

**Signing was solvable offline, contrary to the organisers' FAQ.** The FAQ states that
`devecocli signature generate` does not work outside mainland China and that signing should be
done through the DevEco Studio GUI, which would put a Huawei account and a manual GUI step on
the critical path. The Full SDK contains the complete development identity instead —
`hap-sign-tool.jar`, `OpenHarmony.p12`, the profile-signing certificate and the profile
template — so `scripts/sign-hap.sh` signs locally. The recipe mirrors the organisers'
system-app helper rather than inventing crypto, with one deliberate difference: the helper
forces `app-feature: hos_system_app`, while the SDK's own template already says
`hos_normal_app` with `apl: normal`, which is what this submission actually is.

**A failure whose error message pointed nowhere.** `sign-app` failed with
`Illegal base64 character 20`. `0x20` is a space, and there is no space in any base64 field. The
real cause was a missing **trailing newline** on the `distribution-certificate` PEM in the
profile: the organisers' helper appends one and we had not. The difference was found by
comparing our generated profile against the known-good helper line by line rather than by
reasoning about base64. Recorded in the script so nobody re-derives it.

**Method that made this fast.** Once the SDK was on disk, its `ets/api/**.d.ts` files became the
authoritative reference for the exact targeted version — better than the documentation, and far
better than recollection. Every platform call was checked against them before being written,
which is what turned a hypothetical multi-hour debugging session into two compiler errors that
each took minutes to fix.

### Session 3 — on the device, where the real bugs were

Once DevEco Studio was installed the inner loop became cheap: build about a second, offline sign
about two seconds, install a few seconds, then drive the emulator through `devecocli ui`. That
loop turned three assumptions into three findings, none of which were visible by reading code.

**The gate passed, both halves.** The keyboard enabled and became the active input method, the
panel appeared at exactly 34% of the display height (our own ratio, so our code created it), it
rendered our ArkUI page, it read the hosting field's existing text, and it wrote into that field
from another process. Screenshots are in `docs/evidence/`.

**Finding 1: the engine was built once.** It was constructed in `onCreate` and therefore cached
whatever the API key was at extension start, so a user who configured the keyboard afterwards
silently got the offline path. It is now built per rewrite. No unit test could have found this:
it is a lifecycle fact about the platform, not a property of the engine.

**Finding 2: the extension does not share the app's preferences store.** The input method
extension and the settings UIAbility are in the same bundle, run under the same UID, and both
report the same preferences directory — and they do not share its contents. This was settled by
experiment, not argument: the keyboard was made to write a marker into the store, the ability was
force-stopped and cold-started, and it read nothing. Every file-based channel across that
boundary therefore fails **silently**, which is the worst failure mode available because it is
indistinguishable from "not configured yet". The configuration now crosses explicitly as a
common event, with the keyboard requesting it on start.

**Finding 3, about method rather than code.** Two UI-automation taps missed because their
coordinates were read off a screenshot, which is displayed scaled. The authoritative source for
node bounds is `devecocli ui layout`. After that change every automation step landed first time.

**A defensive catch that hid a real failure.** `BridgeSettings.read` swallowed store errors and
fell back to defaults, so an unreadable store was reported to the user as "no API key set". The
two are now distinguished in the data model and in the message the keyboard shows. This is the
same rule as the design's honest-degradation principle: a degraded path must say *which*
degradation it is.

**A false alarm worth admitting.** A shell check for a leaked key was written as
`if git grep -l PATTERN | head -5`, which tests `head`'s exit status and therefore reports a leak
every time. It printed "LEAK FOUND" with no match at all. The check was rewritten with
`git grep -q`, and then made permanent as `scripts/check-secrets.sh` so that the safety of the
public repository does not depend on a human remembering to look.

**The end-to-end result.** Broken Polish in a system text field produced three labelled Polish
variants from a real model in 1233 ms, and tapping one replaced the field contents —
`replaced 41 characters`. Polish conjugation and diacritics came back correct. That last status
line is also the sharpest available proof that the cursor API is used the right way round:
`deleteForwardSync(41)` removed exactly the 41 characters that preceded the cursor.

### Session 4 — closing an honesty gap by building the missing mode

An audit of the README against the code found a claim with nothing behind it: the product
advertised two modes, and `grep -ri compose app/ core/` returned nothing. The options were to
weaken the claim or to build the mode. We built it, because Compose is where the accessibility
case is strongest.

It needed a new mode in the core contract, a compose instruction and a concept list in the
prompt, an offline fallback that labels itself as offline rather than passing a template off as
composed language, eight tests, and a concept strip in the panel. Everything else already
existed — the engine, the strict parser, the variant rendering, the editor insertion — which is
the payoff of having built the engine platform-agnostic and first.

Result: three concept taps (`jeść`, `później`, `rodzina`) produced `Zjem później z rodziną.`,
with correct Polish aspect and case, and tapping it placed the sentence in the field.

One incidental lesson: fitting the strip meant growing the keyboard panel from 34% to 46% of the
display, and because that ratio is a single named constant the change was one number.

The useful habit here is not the feature. It is that the README was checked against the code,
and the discrepancy was treated as a defect rather than a wording problem.
