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

**Milestone framing.** The ArkTS skeleton deliberately contains no engine wiring at first.
The first milestone is proving that a third-party input method can attach to another
application's text field and write into it, because every other claim depends on that. The
mode buttons state plainly that they are not the model yet.
