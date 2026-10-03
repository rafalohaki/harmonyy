# Environment setup

Reproducible setup for building and running Bridge. Every step says whether it has been
**verified** in this project or is **expected** based on the organisers' documentation and the
official OpenHarmony documentation.

Target platform: OpenHarmony / HarmonyOS, minimum API 20, compiled against API 23, tested
against API 24. Host: macOS on Apple Silicon.

---

## Verified versions

| Component | Version | State |
| --- | --- | --- |
| macOS host | Apple Silicon (arm64) | verified |
| Node.js | 26.9.0 | verified |
| npm | 11.19.1 | verified |
| `@deveco/deveco-cli` | 1.3.4, installed repo-locally into `.tools/` | verified |
| TypeScript (for core type-checking) | 7.0.2 | verified |
| DevEco Studio for macOS (Apple Silicon) | installer downloading | **not yet verified** |
| OpenHarmony SDK | API 23 (OpenHarmony 6.1) | download started, see step 3 |
| Emulator system image | API 24 device profile | **not yet verified** |

Emulator capability limits that shaped the design (from the organisers' comparison table):
no real camera, no NFC, no Bluetooth pairing, no cellular, no biometrics, **no distributed
feature testing**. Simulated accelerometer, gyroscope and GPS are available; so are
notification-listener privileges and system-app installation.

---

## Step 1 — DevEco Studio

`devecocli` is only a wrapper. It needs DevEco Studio or Command Line Tools on disk, and it
says so explicitly:

```
Error: DevEco Studio installation not found in default locations.
Set DEVECO_CLI_STUDIO_PATH to a DevEco Studio installation, or set
DEVECO_CLI_CLT_PATH to a Command Line Tools installation.
```

1. Download **DevEco Studio for macOS (Apple Silicon)** from
   <https://developer.huawei.com/consumer/en/download/>. An account is normally required.
2. Install it (open the `.dmg`, copy the application to `/Applications`). Either drag it in
   Finder, or script it — the script additionally reports the `dataDirectoryName` that step 2
   needs, which is *not* the IDE build number:

   ```bash
   scripts/install-deveco.sh ~/Downloads/DevEco-Studio-*.dmg
   ```

3. **Launch it once** and complete the first-launch setup. This is not optional: that step
   creates `~/Library/Application Support/Huawei/DevEcoStudio<version>/options/`, including
   the `country.region.xml` the next step edits.

Verify:

```bash
scripts/setup-toolchain.sh
```

That script installs `devecocli` repo-locally, checks Node.js ≥ 22, and reports whether
DevEco Studio was found. It deliberately does not search the disk or install anything else.

---

## Step 2 — Switch the region to CN

**Verified as necessary, not yet executed** (it needs DevEco Studio present).

Outside mainland China DevEco Studio only offers a smart-watch emulator profile. With the
region set to `CN` the device manager also offers phone, tablet, 2-in-1 and TV profiles.

The setting lives in a file whose directory name is *not* the IDE build number. It comes from
`dataDirectoryName` in `product-info.json` (for example `DevEcoStudio6.1`).

```bash
scripts/set-devco-region-cn.sh --dry-run   # report the path and the current value
scripts/set-devco-region-cn.sh             # write <countryregion name="CN"/>
```

The script refuses to run while DevEco Studio is open, because the IDE would overwrite the file
on exit, and it keeps a one-time backup next to the original.

---

## Step 3 — SDK

Two paths. The first is the organisers' recommended one; the second needs no account and is
the reason this section exists.

### Path A — DevEco Studio SDK Manager (recommended)

In DevEco Studio: **SDK Manager** → install API 20 (compatible) and API 23 (compile). The
default workflow expects `compileSdkVersion` 23 with `runtimeOS: "OpenHarmony"`.

### Path B — public OpenHarmony mirror, no account required

Huawei publishes full OpenHarmony SDK archives on a public mirror. **Verified by HTTP**: the
following URL exists and serves 1229 MB.

```
https://repo.huaweicloud.com/openharmony/os/6.1-Release/L2-SDK-MAC-M1-PUBLIC.tar.gz
```

`L2-SDK-MAC-M1-PUBLIC` is the **Full SDK for macOS on Apple Silicon**, which is what a
macOS host needs and which includes the system APIs an ordinary public SDK omits. A
`.sha256` sidecar is published next to it.

Related releases on the same mirror, in case a different API level is required:

| Release | API level | SDK archive |
| --- | --- | --- |
| `6.0-Release` | 20 | `L2-SDK-MAC-M1-PUBLIC.tar.gz` |
| `6.1-Release` | 23 | `L2-SDK-MAC-M1-PUBLIC.tar.gz` (1229 MB) |
| `7.0-Release` | 24 | `L2-SDK-MAC-M1-PUBLIC.tar.gz` (1276 MB) |

```bash
scripts/fetch-public-sdk.sh          # download + verify the checksum
# extraction and placement are documented after the archive layout is inspected
```

> The archive layout has **not** been inspected yet, so this document does not claim where the
> extracted directories must be placed. Guessing that is exactly how a setup document becomes
> wrong. The placement instructions are added once the archive is downloaded and its real
> structure is known.

Also on the mirror and potentially useful: `develop_tools/hapsigntoolv2.jar` and
`develop_tools/hmos_app_packing_tool.jar` (HAP signing and packing tools), plus
`develop_tools/previewer/`.

---

## Step 4 — Emulator

**Not yet verified.** The DevEco emulator is the only emulator available on macOS: the Oniro
Emulator targets Windows and Linux, and its graphical launcher is documented as incompatible
with the standard Homebrew QEMU build on macOS. The organisers' guidance is to use DevEco
Studio's emulator on a supported Apple Silicon Mac.

1. In DevEco Studio, open **Device Manager**.
2. Create a virtual device. Phone is the safe default.
3. Download its system image. **This is a manual, GUI-only step and the image is several
   gigabytes.**
4. Start the emulator.

Then verify from the command line:

```bash
scripts/create-emulator.sh --list
devecocli device list
```

Emulator images are not published on the public OpenHarmony mirror, which is why this step
depends on DevEco Studio and, normally, a Huawei account.

---

## Step 5 — Build, run and enable the keyboard

```bash
scripts/sync-core.sh              # copy core/ into the ArkTS module, rewriting imports
scripts/dev-loop.sh tests         # engine tests + reference checks, no SDK needed
scripts/dev-loop.sh build         # produce the .hap
scripts/dev-loop.sh run           # install and launch
scripts/enable-ime.sh <bundle-name>
scripts/enable-ime.sh --status
```

The input method tool used by `enable-ime.sh` is **verified from OpenHarmony documentation** as
supported since API 20:

```
hdc shell ime -e <bundle> -f      enable in full experience mode
hdc shell ime -s <bundle>         switch to it
hdc shell ime -g                  print the current input method
hdc shell ime -l                  list all input methods
```

Two documented constraints worth knowing before debugging: the preset default input method
cannot be disabled, and switching is refused while the screen is locked or a password field is
focused.

---

## Step 6 — Verification checklist

Run these in order; each one is cheap and each failure is unambiguous.

| # | Command | Expected |
| --- | --- | --- |
| 1 | `node --version` | v22 or later |
| 2 | `node --test core/test/` | 84 tests pass |
| 3 | `node scripts/check-refs.mjs` | all checks pass |
| 4 | `scripts/setup-toolchain.sh` | `devecocli` 1.3.4 and DevEco Studio found |
| 5 | `devecocli device list` | the emulator appears |
| 6 | `scripts/dev-loop.sh build` | `BUILD SUCCESSFUL` and a `.hap` on disk |
| 7 | `scripts/dev-loop.sh run` | the app installs and launches |
| 8 | `scripts/enable-ime.sh --status` | Bridge listed and current |
| 9 | `scripts/dev-loop.sh logs` | `inputStart: editor attached` |

Step 9 is the real milestone: it means the keyboard is attached to another application's text
field, which is the claim the whole submission rests on.

---

## Troubleshooting

Drawn from the organisers' FAQ, because these are the failures that actually happen:

| Symptom | Cause and fix |
| --- | --- |
| `devecocli` not found | npm's global bin directory is not on `PATH`; or install it repo-locally with `scripts/setup-toolchain.sh` |
| `devecocli` crashes with a regex `SyntaxError` | an older Node.js earlier on `PATH` (DevEco Studio ships its own). Put Node 22+ first |
| No emulator device types beyond watch | the region is not `CN`; see step 2 |
| No devices in `devecocli device list` | no virtual device created, or its system image was never downloaded, or the emulator was never started. All three are manual |
| `9568332 install sign info inconsistent` | the installed bundle was signed with a different identity. Prefer `install -r`; uninstalling destroys app data, so do not do it silently |
| `9568289 grant request permissions failed` | re-read the permission's APL and ACL eligibility in the exact SDK |
| Build reports missing ArkTS properties inside `oh_modules` | the build SDK is older than the dependency requires; install a newer SDK |
| `signature generate` fails | documented as region-restricted outside mainland China. Create signing material in DevEco Studio instead |

---

## What is not verified yet

Stated plainly so nobody mistakes this document for a claim:

- DevEco Studio is not installed, so nothing past step 1 has been executed.
- The SDK archive has been confirmed to exist and its size verified, but **not downloaded to
  completion, extracted, or inspected**.
- No emulator has been created or started.
- No `.hap` has been built, and the input method has never run.
- The project configuration (`build-profile.json5`, `module.json5`) follows the hackathon
  template and the official IME sample, but it has not been through a compiler.
