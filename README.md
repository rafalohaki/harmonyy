# Bridge — a system input layer that gives people a voice, everywhere

> HackYeah 2026 · OpenHarmony / HarmonyOS Challenge
> Theme lead: **Human-Centric Technology**, combined with **Intelligent Experiences**

## The problem

People with aphasia after a stroke, non-speaking AAC users, people with ALS or cerebral
palsy, and people with dyslexia cannot type the way a standard keyboard assumes they can.

Today they buy an expensive **separate app** for assisted communication — and that app is an
island. A user can compose a sentence inside it, but cannot *send* that sentence in a
messenger, in an email, in a banking app or in a game. Copy-paste is a prosthesis, not a
solution.

Nobody ships this as a **system capability**, because on closed platforms the input layer is
not something an outside developer gets to extend.

## What Bridge is

Bridge is not another app. It is an **input method** — a system component that replaces the
keyboard for **every text field on the device**. Two modes, one capability:

| Mode | Interaction | Who it is for |
| --- | --- | --- |
| **Rewrite** | Type however you can, then tap *Correct / Plain / Polite*. The field text is rewritten and replaced in place. | Dyslexia, aphasia, non-native speakers, anyone writing to an office instead of a friend |
| **Compose** | Tap a few semantic tokens (🍽️ 🕐 1) instead of typing. A full grammatical sentence is produced, in the register of the app you are in. | Non-speaking users, severe motor impairment |

Because the same engine serves both modes, we build **one platform capability and take it
end to end** rather than five shallow integrations.

## Why an open platform is the point

`InputMethodExtensionAbility` (IME Kit) is what makes this possible: a third-party keyboard
receives the **text editor proxy** for whatever app currently owns the field, so it can read,
rewrite and insert text system-wide. The European Accessibility Act makes this a compliance
problem for European products, not a niche favour — and it is exactly the kind of extension
point a vendor-controlled platform does not hand out.

## Privacy is a product feature, not a disclaimer

The rewrite engine runs against a remote LLM, and **that is a privacy event**. Bridge handles
it explicitly:

- **Local PII scrubbing before any request.** E-mails, phone numbers, PESEL, IBAN, card-like
  digit runs and URLs are replaced with typed placeholders, sent as placeholders, and
  restored locally in the response. The model never receives the real values.
- **A visible counter** on the keyboard: *"3 items hidden from the model"*.
- **A deterministic offline fallback.** If the network, the timeout or the model itself
  fails, a local rule engine takes over and the keyboard says so instead of pretending.
- **The API key never enters this repository.** It is typed once into the app's settings
  screen and stored in device preferences.

See [`docs/AI_INTEGRATION.md`](docs/AI_INTEGRATION.md) for data handling, limitations and
validation, and [`AI_WORKFLOW.md`](AI_WORKFLOW.md) for how this was built with AI tooling.

## Platform capability used

| Capability | Why it is load-bearing |
| --- | --- |
| `InputMethodExtensionAbility` + `InputMethodEngine` / `TextEditorProxy` | The whole product: system-wide text read/rewrite/insert. Not available to ordinary apps on iOS at all |
| `inputMethodAbility` lifecycle events | Attach/detach to the active editor, so we know when a field is focused |
| `EditorAttribute.bundleName` via `editorAttributeChanged` (API 14+) | The keyboard knows **which app owns the field**, so a rewrite can match its register — casual in a messenger, formal in an e-mail client |
| `@ohos.net.http` | The remote rewrite engine |
| `hdc shell ime -e/-s` (IME tool, API 20+) | Reproducible enable/switch from the command line instead of clicking through Settings |

No privileged permissions, no system-app signing, no `hos_system_app` profile. That is a
deliberate scope decision: it removes the largest schedule risk from a sub-24-hour build.

## Repository layout

```
core/       Platform-agnostic rewrite engine (ArkTS-compatible TypeScript) + tests
app/        The ArkTS/ArkUI application and the input method extension (added after SDK install)
scripts/    Toolchain setup, IME enablement, dev loop
docs/       Architecture and AI integration documentation
```

## Required deliverables, and where they live

| # | Deliverable | Location | State |
| --- | --- | --- | --- |
| 1 | Public source code repository | this repository | ready |
| 2 | Reproducible setup, build, install and launch instructions | [Build and run](#build-and-run), [`scripts/`](scripts) | ready for the toolchain steps; verified up to the SDK boundary |
| 3 | A working `.hap` package | produced by `scripts/dev-loop.sh build` | **not yet** — blocked on the DevEco download |
| 4 | A brief recorded demonstration | plan and shot list in [`docs/DEMO.md`](docs/DEMO.md) | plan ready, not yet recorded |
| 5 | Architecture and implementation description | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | ready |
| 6 | `AI_WORKFLOW.md` | [`AI_WORKFLOW.md`](AI_WORKFLOW.md) | ready, updated as work proceeds |
| 7 | AI integration documentation | [`docs/AI_INTEGRATION.md`](docs/AI_INTEGRATION.md) | ready |

## Status

Work in progress, built during the hackathon window. This README is updated as the build
progresses — reproducibility is a judged criterion and the easiest one to lose.

| Stage | State |
| --- | --- |
| Rewrite engine core + unit tests | **done** — 58 tests pass, strict `tsc --noEmit` clean |
| Toolchain (DevEco Studio / SDK / emulator) | installer downloading; this is the critical path |
| ArkTS input method skeleton | written, **not yet compiled** (needs the SDK) |
| `.hap` on the emulator | not yet — the next milestone |
| Demo recording | not yet |

The first milestone is not the AI. It is proving that a third-party input method
can attach to another application's text field and write into it, because every
other claim in this README depends on that. It is isolated in
[`KeyboardController.ets`](app/entry/src/main/ets/inputmethod/KeyboardController.ets)
and the mode buttons in the keyboard deliberately say that they are not the model
yet. See the go/no-go gate in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Build and run

Reproducible from a clean checkout once DevEco Studio is installed:

```bash
# 1. DevEco CLI, and a report of what is still missing
scripts/setup-toolchain.sh

# 2. Region switch to CN (once, with DevEco Studio closed).
#    Without it the emulator only offers a watch profile.
scripts/set-devco-region-cn.sh

# 3. A phone emulator. The system image is several gigabytes.
scripts/create-emulator.sh

# 4. Engine tests - these need no SDK at all
scripts/dev-loop.sh tests

# 5. Exercise the engine end to end against a local mock model, or your real one
scripts/dev-loop.sh engine
BRIDGE_API_KEY=sk-... node scripts/try-engine.mjs

# 6. Build, then install and launch
scripts/dev-loop.sh build
scripts/dev-loop.sh run

# 7. Enable and switch to the Bridge keyboard
scripts/enable-ime.sh <bundle-name>
scripts/enable-ime.sh --status

# 8. Capture evidence from the emulator
scripts/dev-loop.sh shot rewrite-demo
```

`scripts/try-engine.mjs` reuses the exact shipped core, so what it prints is what the keyboard
will show. It is how the prompt was validated before any device existed, and step 3 of
[`docs/SETUP.md`](docs/SETUP.md#step-6--verification-checklist) relies on it.

The engine is the single source of truth and is copied into the ArkTS module by
`scripts/sync-core.sh`; never edit the copies under `app/entry/src/main/ets/core/`.

Exact versions this was verified against: Node.js 26.9.0, npm 11.19.1,
`@deveco/deveco-cli` 1.3.4, DevEco Studio for macOS (Apple Silicon).


## Running the engine tests

Requires only Node.js 22+ (Node 26 runs TypeScript natively):

```bash
node --test core/test/
```
