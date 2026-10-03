# HackYeah 2026 — submission copy

Paste-ready text for the HackTribe form. English, because the repository README is kept
authoritative in English. Blocks marked **paste** go into the form as they are.

---

## Project Name

**paste**

> Bridge — a system keyboard that gives people a voice

---

## Problem

**paste**

> Millions of people cannot type the way a standard keyboard assumes. The WHO counts
> ~12.2 million strokes a year, and roughly a third of stroke survivors live with aphasia —
> writing a single correct sentence becomes a struggle. Add dyslexia (5–10% of the
> population, around 2 million people in Poland), motor impairments such as ALS or cerebral
> palsy, and non-native speakers who must write to offices in a language they do not
> command.
>
> Today the assistive answer is a separate, expensive "communicator" app — and that app is
> an island: the user can compose a sentence only inside it, then cannot send that sentence
> in a messenger, an e-mail or a banking app. Copy-paste is a prosthesis, not a solution.
> Nobody ships typing assistance as a *system capability*, because on closed mobile
> platforms the input layer is not extensible by outside developers.
>
> Since 28 June 2025 the European Accessibility Act makes accessible digital products a
> legal requirement in the EU — so this is a compliance problem for every European product,
> not a niche favour.

---

## Solution

**paste**

> Bridge is not another app — it is an **input method**. Built on HarmonyOS IME Kit
> (`InputMethodExtensionAbility`, API 20+), it replaces the keyboard for **every text field
> on the device**, with two modes served by one engine:
>
> - **Rewrite** — type however you can (`ja chciec isc do domu`), tap *Correct / Plain /
>   Polite*, and the field text is rewritten in place. Three variants come back
>   (minimal / natural / formal), and the register follows the app that owns the field.
> - **Compose** — a non-speaking user picks concepts (🍽️ ⏰ 👨‍👩‍👧) and the engine composes
>   a grammatical sentence (`Zjem później z rodziną.`) inserted into the field.
>
> Privacy is a product feature: e-mails, phone numbers, PESEL, IBAN and card-like digit runs
> are scrubbed **on the device** before any request and restored afterwards — the model never
> receives the real values, and a visible counter says how many items were hidden. If the
> model is unreachable, a deterministic offline fallback keeps the keyboard usable and says
> so instead of failing silently.
>
> Everything is verified on a HarmonyOS 6.1.1(24) emulator — including a rewrite inside the
> Huawei browser's own search field, a third-party app that knows nothing about Bridge
> ([`docs/evidence/10-rewrite-in-browser.jpeg`](evidence/10-rewrite-in-browser.jpeg)).
> The user benefit: one system capability instead of a separate app per use case, working in
> every field on the device, from a public repository with a reproducible build.

---

## Idea stage

Select **New Idea** — the repository's first commit is from 3 October (HackYeah day);
nothing existed before the event.

---

## What's done so far and goal of your project

**paste**

> Built entirely during HackYeah 2026, from an empty repository to a verified system:
> a platform-agnostic rewrite engine (96 unit tests, strict TypeScript), an ArkTS input
> method that attaches to *other apps'* text fields and reads, rewrites and inserts text,
> an offline-signed `.hap` built and installed on a HarmonyOS 6.1.1 emulator, and
> on-device verification of rewrite, compose, on-device PII scrubbing and the offline
> fallback. An 81-second demonstration video was rendered from twelve stills captured
> on the device — including the rewrite working in a third-party app's field.
> Goal for the event, reached: one end-to-end system capability, not a mock-up.

---

## Team status / skills

Leave **Looking for team members** selected if that is still true. Skills to tick:

- Web & Mobile (ArkTS / HarmonyOS is the core of this project)
- AI & Data Science (prompting, latency, register matching)
- Design & UX (AAC iconography, accessible layouts)
- QA & Testing

**Skills comment — paste**

> The core is ArkTS/HarmonyOS (`InputMethodExtensionAbility`), so a Web & Mobile developer
> comfortable with typed UI frameworks would help most. AI & Data Science for prompt and
> latency work on the rewrite engine; Design & UX for the AAC concept strip and the
> onboarding; QA for device-matrix testing on real HarmonyOS hardware.

---

## Video presentation

File to upload: `demo/out/bridge-demo.mp4` — 81 s, 1920×1080, 30 fps, ~30 MB.
Upload it to YouTube as **Listed** (or public) and paste the link into the form field.
The storyboard it was rendered from is in [`DEMO.md`](DEMO.md); every frame is a real
device capture, and the closing card says so.

## Cover image

File to upload: `docs/hackyeah-cover.jpg` — 1920×1080, ~115 KB. It carries the strongest
single frame: the rewrite inside the Huawei browser's search field, a third-party app.

## Website / Code Repository

Both fields: **https://github.com/rafalohaki/harmonyy**

## Instructions on how to open project

**paste**

> 1. Clone `https://github.com/rafalohaki/harmonyy`. The engine alone needs only Node.js
>    22+: `node --test core/test/` (96 tests).
> 2. Exercise the engine end to end against a mock or real model:
>    `scripts/dev-loop.sh engine`, or `BRIDGE_API_KEY=sk-... node scripts/try-engine.mjs`.
> 3. A full `.hap` build needs DevEco Studio 6.1.1 with the HarmonyOS SDK:
>    `scripts/setup-toolchain.sh` reports what is missing, then
>    `scripts/dev-loop.sh build` + `scripts/sign-hap.sh` produce
>    `dist/bridge-1.0.0-signed.hap`.
> 4. On an emulator: `hdc install dist/bridge-1.0.0-signed.hap`, then
>    `scripts/enable-ime.sh com.bridge.ime` to switch the system keyboard to Bridge.
> 5. Full step-by-step: README → **Build and run**; architecture in `docs/ARCHITECTURE.md`,
>    AI data handling in `docs/AI_INTEGRATION.md`, how AI tooling built this in
>    `AI_WORKFLOW.md`.

---

## Presentation (PDF/PPTX, ≤10 MB)

Not yet produced. If wanted: a short deck (problem → why a system keyboard is only possible
on an open input layer → two modes → privacy → live proof frame → roadmap) can be generated
from this repository's docs; ask and it will be built.
