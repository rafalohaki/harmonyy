**English** · [Polski](README.pl.md)

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
keyboard for **every text field on the device**.

**Two modes, one capability:**

| Mode | Interaction | Who it is for | State |
| --- | --- | --- | --- |
| **Rewrite** | Type however you can, then tap *Correct / Plain / Polite*. The field text is rewritten in place. | Dyslexia, aphasia, non-native speakers, anyone writing to an office instead of a friend | **working**, verified on the emulator |
| **Compose** | Pick concepts (🍽️ ⏰ 👨‍👩‍👧) instead of typing; a grammatical sentence is produced in the register of the app you are in. | Non-speaking users, severe motor impairment | **working**, verified on the emulator |

Because one engine serves both modes, we build **one platform capability and take it end to
end** rather than five shallow integrations.

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
app/        The ArkTS/ArkUI application and the input method extension
scripts/    Toolchain setup, IME enablement, dev loop, checks
docs/       Architecture, AI integration, environment, demo plan, decision log
dist/       The signed .hap, ready to install
```

Start with **[`docs/DECISIONS.md`](docs/DECISIONS.md)**: it is the ledger of the decisions this
project follows, written as checkable statements rather than prose. Every pull request is
reviewed against it by [Prelint](https://prelint.com), so a change that drifts from a decision
gets caught before it merges rather than after.

## Required deliverables, and where they live

| # | Deliverable | Location | State |
| --- | --- | --- | --- |
| 1 | Public source code repository | this repository | ready |
| 2 | Reproducible setup, build, install and launch instructions | [Build and run](#build-and-run), [`scripts/`](scripts) | ready for the toolchain steps; verified up to the SDK boundary |
| 3 | A working `.hap` package | [`dist/bridge-1.0.0-signed.hap`](dist/bridge-1.0.0-signed.hap), produced by `scripts/dev-loop.sh build` + `scripts/sign-hap.sh` | **built, signed and installed on the emulator** as an ordinary app |
| 4 | A brief recorded demonstration | [`demo/`](demo) — Remotion composition over committed on-device stills; renders to `demo/out/bridge-demo.mp4`; storyboard in [`docs/DEMO.md`](docs/DEMO.md) | **recorded** — 81 s from twelve stills captured on-device |
| 5 | Architecture and implementation description | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | ready |
| 6 | `AI_WORKFLOW.md` | [`AI_WORKFLOW.md`](AI_WORKFLOW.md) | ready, updated as work proceeds |
| 7 | AI integration documentation | [`docs/AI_INTEGRATION.md`](docs/AI_INTEGRATION.md) | ready |

## Verified on the emulator

Not a mock-up. Captured on a HarmonyOS 6.1.1(24) phone emulator; screenshots are in
[`docs/evidence/`](docs/evidence).

```
field text : ja chciec jutro przyjsc na spotkanie o 10
status line: model: 1233 ms, 0 hidden
variants   : minimal  Ja chcę jutro przyjść na spotkanie o 10.
             natural  Chcę przyjść jutro na spotkanie o 10.
             formal   Będę na spotkaniu o 10 jutro.
after a tap: the field contains the corrected sentence
             status line: replaced 41 characters
```

Polish conjugation and diacritics come back correct. The `replaced 41 characters` line is also
the sharpest available proof that the cursor API is used the right way round: exactly the
characters before the cursor were removed and the replacement landed in their place.

**Compose**, from three concept taps — `jeść`, `później`, `rodzina`:

```
picked     : jeść, później, rodzina
status line: model: 1490 ms, 0 hidden
variants   : faithful  Zjem później z rodziną.
             natural   Będę jeść później z rodziną.
             expanded  Zamierzam zjeść później z rodziną.
after a tap: the field contains "Zjem później z rodziną."
```

Correct Polish aspect and case, from three emoji. **A user who cannot type produced a
grammatical sentence, in another application's text field.**

Also verified with screenshots in [`docs/evidence/`](docs/evidence): `2 hidden` personal
identifiers withheld from the model and restored locally, and an unreachable endpoint degrading
to `offline: The model service could not be reached.` with a usable offline result.

**And in an app that knows nothing about Bridge.** The same rewrite ran in the Huawei browser's
own search field — a third-party app with no integration and no awareness that an input method
could rewrite its text. `ja chciec isc do domu` came back as three correct variants in 0.8 s,
and the panel said plainly what happened: *Ready — Rewritten by the model in 0.8 s — nothing
personal left this device*. Screenshot:
[`docs/evidence/10-rewrite-in-browser.jpeg`](docs/evidence/10-rewrite-in-browser.jpeg). That
frame is the product claim in one image: Bridge is a system component, so it shows up in text
fields that belong to other apps.

## Status

| Stage | State |
| --- | --- |
| Rewrite engine core + unit tests | **done** — 96 tests pass, strict `tsc --noEmit` clean |
| Toolchain | **done** — DevEco Studio 6.1.1.280, Full SDK verified by checksum, emulator image installed |
| ArkTS application | **compiles** — `BUILD SUCCESSFUL` |
| Signing | **done offline** with the SDK's development identity; `app-feature: hos_normal_app` |
| `.hap` installed on the emulator | **done** |
| Input method gate: attach, read and write in another app | **passed**, with screenshots |
| Rewrite through a real model, applied to the field | **done**, see above |
| Rewrite in a third-party app's own field | **done** — the Huawei browser search field, [`docs/evidence/10-rewrite-in-browser.jpeg`](docs/evidence/10-rewrite-in-browser.jpeg) |
| Personal-data scrubbing, evidenced on the device | **done** — `2 hidden`, and the values restored in the variants |
| Offline fallback on failure, evidenced on the device | **done** — an unreachable endpoint produced `offline: The model service could not be reached.` and a usable offline result |
| Compose mode (concept strip) | **done** — three concept taps produced a grammatical Polish sentence, applied to the field |
| Demo recording | **done** — `demo/out/bridge-demo.mp4`, 81 s, rendered from twelve on-device stills with Remotion |

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

# 6. Build, sign, then install and launch
scripts/dev-loop.sh build
scripts/sign-hap.sh
scripts/dev-loop.sh run

# 7. Enable and switch to the Bridge keyboard
scripts/enable-ime.sh com.bridge.ime
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
