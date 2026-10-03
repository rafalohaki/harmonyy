# Decision log

This is the ledger of decisions this project is expected to follow.

It exists for two reasons. First, a hackathon moves fast and decisions otherwise live only in
someone's memory and in the commit log. Second, this repository is reviewed by
[Prelint](https://prelint.com), which reads markdown like this and checks every pull request
against it for drift. **The clearer each statement is, the sharper that review is**, so every
entry below states something that can be checked against code rather than something that sounds
good.

Each entry has: the decision, the reasoning, and what a violation would look like.

---

## D1 — One platform capability, taken end to end

**Decision.** The product extends the system through exactly one extension point: the input
method (`InputMethodExtensionAbility`). No second platform surface is added.

**Reasoning.** The organisers' own scoping advice is "pick one capability and make it work end
to end; breadth reads as unfinished". A second integration would dilute the depth without
adding a user.

**A violation looks like:** a second `extensionAbilities` entry of a different type being added
to solve a product problem, or a feature being implemented as a normal app screen when it
belongs in the input path.

**Where it lives:** `app/entry/src/main/module.json5`, `docs/ARCHITECTURE.md` §1.

---

## D2 — No privileged identity

**Decision.** The HAP installs as an **ordinary application**: `app-feature` is
`hos_normal_app`, `apl` is `normal`, there is no ACL list, and the only requested permission is
`ohos.permission.INTERNET`. No `hos_system_app`, no system API, no system-app signing.

**Reasoning.** The product needs none of it, and privileged identity is the largest schedule and
acceptance risk in this ecosystem. The accessibility-service route was rejected for exactly this
reason.

**A violation looks like:** a `requestPermissions` entry beyond `INTERNET`, an `acls` block in
the signing profile, or code calling an API the compiler flags as a system API.

**Where it lives:** `app/entry/src/main/module.json5`, `scripts/sign-hap.sh`,
`docs/ARCHITECTURE.md` §7.

---

## D3 — No secret in the repository

**Decision.** No API key, token, password or private key may appear in a tracked file. The key is
entered on the device and stored in device preferences.

**Reasoning.** The repository is public. A key committed once is leaked permanently, and the
challenge's hygiene criterion says so explicitly.

**A violation looks like:** any provider key prefix in a tracked file, a `.p12`/`.p7b`/`.jks`
under version control, or an endpoint carrying a credential in a query string.

**Where it lives:** `scripts/check-secrets.sh`, which runs as part of `scripts/dev-loop.sh tests`
and refuses to pass when it finds any of the above.

---

## D4 — Every degradation is labelled, and nothing throws

**Decision.** The engine never throws for an expected failure — network error, timeout, HTTP
error, malformed model output, or a dropped placeholder. It returns an outcome whose `source`
says whether the answer came from the model or from the offline engine, and the keyboard renders
the reason verbatim.

**Reasoning.** A silently degraded answer is a lie about the product's state. The organisers ask
for exactly this honesty: "say plainly what is real and what is fake".

**A violation looks like:** a new `throw` on an expected failure path, a fallback that leaves
`fallbackReason` empty, or UI that shows offline output without saying it is offline.

**Where it lives:** `core/src/engine.ts`, `core/test/engine.test.ts`,
`app/entry/src/main/ets/inputmethod/pages/Index.ets`.

---

## D5 — Documentation claims are backed by code

**Decision.** No feature is described in the README or the architecture notes that does not
exist in the code.

**Reasoning.** Claims are a judged criterion, and an unsupported claim contaminates trust in
every other claim. This was violated once — the README advertised a Compose mode that did not
exist — and was fixed by **building the mode**, not by softening the wording.

**A violation looks like:** a feature named in the README with no corresponding module, symbol or
test, or a status table that says "done" for something never run.

**Where it lives:** `README.md`, `docs/ARCHITECTURE.md`, `AI_WORKFLOW.md`.

---

## D6 — Personal data does not leave the device

**Decision.** Structured identifiers are removed **locally, before the request**, and restored
**locally, after** it. The model sees placeholders only. If a placeholder cannot be restored, the
whole response is rejected rather than partially restored.

**Reasoning.** The rewrite path is a privacy event, and a partially restored answer could
silently swap or lose a value.

**A violation looks like:** sending raw field text to the provider, restoring a response that
dropped a placeholder, or logging any part of the outgoing text.

**Where it lives:** `core/src/redact.ts`, `core/src/engine.ts`,
`app/entry/src/main/ets/net/ArkHttpTransport.ets`.

---

## D7 — The keyboard collects only what it needs

**Decision.** The only permission is `ohos.permission.INTERNET`. Every permission must carry a
user-facing reason. No user text is written to disk or to logs; only the fallback reason and
latency counters are recorded.

**Reasoning.** An input method sees everything the user types. Anything it stores is a liability
it created.

**A violation looks like:** a new permission without a `reason` string, user text appearing in a
`hilog` call, or field content being persisted.

**Where it lives:** `app/entry/src/main/module.json5`,
`app/entry/src/main/ets/inputmethod/KeyboardController.ets`.

---

## D8 — The engine stays platform-agnostic

**Decision.** Files under `core/` import nothing from the platform. The network is reached only
through the injected `LlmTransport` interface.

**Reasoning.** It is what let 92 tests and a strict type-check run before any SDK existed, and it
is what made the pre-planned pivot to another product concept survivable.

**A violation looks like:** an `@kit.*` or `@ohos.*` import inside `core/`, or an HTTP call made
from core rather than through the transport.

**Where it lives:** `core/src/contracts.ts`, `scripts/sync-core.sh`,
`docs/ARCHITECTURE.md` §2.

---

## D9 — The project builds from a clean checkout

**Decision.** Every step between a fresh clone and a running keyboard is a committed script:
toolchain, SDK, emulator, core sync, build, offline sign, keyboard enablement.

**Reasoning.** Reproducibility is a judged criterion and the easiest one to lose.

**A violation looks like:** a step that exists only in prose, a script that assumes state from a
previous manual step, or a hard-coded absolute path to a machine-local directory in the default
path of a script.

**Where it lives:** `scripts/`, `docs/SETUP.md`.

---

## D10 — The system is not modified

**Decision.** The deliverable is an installable component that adds a capability **without
modifying the system**. No OpenHarmony source patch, no replaced system bundle, no
`reboot-to-reload`.

**Reasoning.** The challenge requires an improvement delivered as an installable application or
component; patching the platform would be a different submission and would not be reproducible
for a judge.

**A violation looks like:** a change under a system path, an instruction to flash an image, or a
dependency on a custom system build.

**Where it lives:** `docs/ARCHITECTURE.md` §7.

---

## D11 — Verified behaviour is stated only from observed evidence

**Decision.** A behaviour is described as verified only when it was observed on the emulator, and
the evidence is committed. Untested claims are marked as such, in the same document that makes
them.

**Reasoning.** The organisers' standard is four independent gates: build, install, launch, and
observe. A successful build is not evidence of working behaviour.

**A violation looks like:** a status table claiming a feature works with no screenshot, log line
or test behind it; or a "verified" note describing something read from documentation rather than
run.

**Where it lives:** `README.md` status table, `docs/evidence/`, `AI_WORKFLOW.md` §6.

---

## D12 — Failures found during work are recorded, not smoothed over

**Decision.** Every defect found by testing, and every assumption proven wrong, is written into
`AI_WORKFLOW.md` with the evidence that found it — including the ones that were our own mistakes.

**Reasoning.** The challenge asks for known limitations, unsuccessful approaches and lessons
learned. A submission that reports only its successes is less useful and less credible.

**A violation looks like:** a fix committed with no note of the failure that motivated it, or a
limitation removed from the documentation once it became inconvenient.

**Where it lives:** `AI_WORKFLOW.md` §5 and §6.
