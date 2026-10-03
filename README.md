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

## Status

Work in progress, built during the hackathon window. This README is updated as the build
progresses — reproducibility is a judged criterion and the easiest one to lose.

| Stage | State |
| --- | --- |
| Rewrite engine core + unit tests | implemented, tested with Node |
| Toolchain (DevEco Studio / SDK / emulator) | **blocked on a manual Huawei download** |
| ArkTS input method extension | not started |
| `.hap` on the emulator | not yet |
| Demo recording | not yet |

## Build and run

Not yet reproducible — this section is filled in as each step lands. The intended path is:

1. Install DevEco Studio (macOS, Apple Silicon) and complete its first-launch setup.
2. `scripts/setup-toolchain.sh` — installs `devecocli`, switches the DevEco region to `CN`
   (without this the emulator only offers a watch profile), and prepares a phone emulator.
3. `devecocli build` in `app/`, then `devecocli run`.
4. `scripts/enable-ime.sh` — enables and switches to the Bridge keyboard.

Details, exact versions and the current reality of each step are in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Running the engine tests

Requires only Node.js 22+ (Node 26 runs TypeScript natively):

```bash
node --test core/test/
```
