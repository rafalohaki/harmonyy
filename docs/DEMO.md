# Demo — storyboard and recording plan

The organisers' advice is explicit: *"Record the demo before you are out of time, not
after."* This is the plan, written before the recording so the recording is a rehearsal
rather than an improvisation.

Target length: **2 to 3 minutes.** Recorded on the DevEco Studio emulator; there is no
physical device in this setup, and the recording says so rather than implying otherwise.

---

## 1. What the demo must prove

Ranked, because a demo that tries to prove five things proves none:

1. **The keyboard is a system component, not an app.** It rewrites text inside a *different*
   application's text field. This is the whole platform claim.
2. **The rewrite is real**, on real text, in a real field — not a mock-up.
3. **Personal data does not reach the model.** The counter is visible while it happens.
4. **Failure is handled honestly.** Show the offline path, not just the happy path.
5. **It is reproducible.** The setup is a script, shown on screen.

---

## 2. Preconditions

```bash
# Emulator running and visible
scripts/create-emulator.sh --list
devecocli device list

# Build, install, launch
scripts/dev-loop.sh build
scripts/dev-loop.sh run

# Enable and switch to the Bridge keyboard (IME tool is API 20+)
scripts/enable-ime.sh <bundle-name>
scripts/enable-ime.sh --status

# Confirm the field-attachment signal in the logs before recording
scripts/dev-loop.sh logs      # expect: inputStart: editor attached
```

Set the API key once in the Bridge settings screen. Do **not** put it in a config file, and
do **not** show it on camera — blur or avoid that screen.

Clear the log buffer immediately before recording so the evidence shown is from this take:

```bash
hdc shell hilog -r
```

---

## 3. Shot list

| # | Time | On screen | Narration (English) | Why it is in the demo |
| --- | --- | --- | --- | --- |
| 1 | 0:00–0:15 | The emulator home screen, then a messaging app with an empty text field | "Standard keyboards assume you can type. Many people cannot — after a stroke, with aphasia, dyslexia, or severe motor impairment. They buy an app instead, and that app is an island: they can compose a sentence but cannot send it anywhere." | Names the user and the problem in the first fifteen seconds |
| 2 | 0:15–0:30 | Switch the input method to Bridge (`scripts/enable-ime.sh` on screen, or the keyboard picker) | "Bridge is not an app. It is an input method — a system component, so it works in *every* text field on the device." | The platform claim, shown rather than asserted |
| 3 | 0:30–0:55 | Type deliberately broken text in the messenger, e.g. `ja chciec jutro przyjsc na spotkanie o 10` | "This is how I actually write." | Sets up the transformation |
| 4 | 0:55–1:20 | Tap **Correct**, then a variant card. The field text changes in place. | "One tap, and the field is rewritten — without leaving the app I was already in." | The core interaction |
| 5 | 1:20–1:45 | Type a message containing an address, then tap **Plain** or **Polite**. The status line shows `model: 812 ms, 1 hidden`. | "The counter says one item was hidden. That e-mail address was removed on the device, before anything was sent, and put back locally afterwards. The model never saw it." | The privacy mechanism, demonstrated rather than claimed |
| 6 | 1:45–2:10 | Remove the API key (or disable networking) and repeat a rewrite. The status line reads `offline: ...`, the variants are plainer, and the keyboard keeps working. | "When the network or the model fails, Bridge does not pretend. It falls back to a deterministic engine on the device and tells you which one answered." | Failure handling is a scored criterion, and honesty is explicitly requested |
| 7 | 2:10–2:30 | The terminal: `scripts/dev-loop.sh tests` showing the test count, and `git log --oneline` | "Everything here is reproducible from the repository, and the engine's behaviour under model failure is covered by tests." | Reproducibility, in ten seconds |

### What is real, and what is not

State this out loud on camera, as the organisers ask:

- **Real:** the input method, the system-wide text access, the rewrite round trip, the PII
  scrubbing, the offline fallback, the emulator it runs on.
- **Not real:** there is no on-device model — the rewrite path uses a remote
  OpenAI-compatible endpoint. The emulator is not a physical device. The app-name-to-register
  mapping is a small heuristic, not a classifier.

---

## 4. Recording

```bash
# Option A: host-side screen capture while the emulator is visible
#   macOS: Shift-Cmd-5, select the emulator window

# Option B: device-side screenshots as still evidence, scripted
scripts/dev-loop.sh shot 01-before-rewrite
scripts/dev-loop.sh shot 02-variants
scripts/dev-loop.sh shot 03-pii-hidden
scripts/dev-loop.sh shot 04-offline-fallback
```

Screenshots land in `docs/evidence/`. They are the reproducible half of the evidence: the
video shows the interaction, the screenshots prove the state without trusting a recording.

---

## 5. Fallbacks

| Risk | Plan |
| --- | --- |
| No network in the emulator | Shoot shots 1–4 and 6 first; they do not need the model at all. The offline path is a feature, not an apology |
| Model is slow on camera | Rehearse with the timeout in mind; the keyboard shows `working...` and the buttons disable, so the wait reads as intentional |
| IME does not attach to a particular app's field | Record in a different app. The capability is system-wide, so the demo is not tied to one host |
| Emulator window will not focus for capture | Use device-side screenshots plus narration over stills, and say that is what happened |

---

## 6. Checklist before recording

- [ ] `scripts/dev-loop.sh tests` passes (engine tests and reference checks)
- [ ] `scripts/dev-loop.sh build` succeeds
- [ ] `.hap` installed and launched on the emulator
- [ ] `scripts/enable-ime.sh --status` reports Bridge as the active input method
- [ ] Logs show `inputStart: editor attached`
- [ ] API key set, and not visible anywhere on camera
- [ ] `hdc shell hilog -r` run immediately before the take
- [ ] Shot list rehearsed once end to end
