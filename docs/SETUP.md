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

> **The archive has now been downloaded, verified and inspected.** Its real layout is recorded
> below, because it is not what the name suggests: it is a container of five nested component
> archives, not a ready-to-use SDK directory.

#### What the archive actually contains (verified)

`L2-SDK-MAC-M1-PUBLIC.tar.gz` extracts to a single path, `sdk/packages/ohos-sdk/darwin/`,
holding five nested ZIPs:

| Nested archive | Size | Contents after extraction |
| --- | --- | --- |
| `native-darwin-arm64-6.1.0.31-Release.zip` | 891 MB | NDK: C/C++ headers, libraries, toolchain |
| `previewer-darwin-arm64-6.1.0.31-Release.zip` | 210 MB | the UI Previewer |
| `ets-darwin-arm64-6.1.0.31-Release.zip` | 69 MB | ArkTS API declarations, `ets-loader`, `kits`, `component` |
| `js-darwin-arm64-6.1.0.31-Release.zip` | 56 MB | JS API declarations and `ace-loader` |
| `toolchains-darwin-arm64-6.1.0.31-Release.zip` | 22 MB | `hdc`, `restool`, `idl`, `ark_disasm`, `lib/` |

Extracting all five produces the component root, **3.9 GB** in total:

```
ets/        api/  arkts/  build-tools/ets-loader/  component/  kits/
js/         api/  build-tools/ace-loader/
native/     NDK headers, libraries and toolchain
previewer/  the Previewer
toolchains/ hdc  restool  idl  ark_disasm  lib/  ...
```

Each component carries an `oh-uni-package.json` that states its own identity, which is how the
toolchain discovers it. Verified values:

```json
{ "apiVersion": "23", "displayName": "Ets", "path": "ets",
  "releaseType": "Release", "version": "6.1.0.31" }
```

`apiVersion: "23"` matches this project's `compileSdkVersion: 23` exactly. The ArkTS compiler is
present for this host architecture at
`ets/build-tools/ets-loader/bin/ark/build-mac/bin/es2abc`.

#### Two things this SDK removes, and the one thing it does not

`toolchains/lib/` in the Full SDK contains the **complete offline signing material**:

```
hap-sign-tool.jar
OpenHarmony.p12
OpenHarmonyProfileRelease.pem
OpenHarmonyProfileDebug.pem
UnsgnedReleasedProfileTemplate.json
UnsgnedDebugProfileTemplate.json
```

That matters, because `devecocli signature generate` is documented as region-restricted outside
mainland China and the organisers' answer is to sign through the DevEco Studio GUI. With the
Full SDK there is a third option that needs **no Huawei account and no GUI**: sign the `.hap`
offline with the SDK's public development material. The required HAP deliverable therefore does
not depend on account services. `toolchains/hdc` is also present, so device communication does
not require the IDE either.

What the SDK does **not** contain is the build orchestrator (`hvigor`), the package manager
(`ohpm`), or the emulator. The first two come with Command Line Tools or DevEco Studio; the
emulator comes only with DevEco Studio, and that is the reason Studio is still required.

#### Placement

The component root is the directory that directly contains `ets/`, `js/`, `native/`,
`previewer/` and `toolchains/`. DevEco Studio and hvigor resolve an SDK from a configured root
(for example through `DEVECO_SDK_HOME`), and the organisers' documentation describes a known
shape of `<parent>/sdk/default/openharmony/{ets,js,...}`.

**This placement is not claimed as verified.** The authoritative answer is one minute of
checking: once DevEco Studio is installed, look at the directory its SDK Manager creates and
compare. That is deliberately left as an empirical step rather than a guess, because a wrong
SDK path produces a confusing build error rather than an honest one.

**Measured throughput, which is why this path is worth preferring.** Downloading both archives
simultaneously on the same connection, the public mirror sustained **1.47 MB/s** while Huawei's
developer download portal for DevEco Studio sustained **0.20 MB/s** — roughly seven times
faster. For a 1.2 GB SDK that is the difference between eleven minutes and over an hour and a
half. The mirror is also not rate-limited per account, has no login, and publishes checksums.

That comparison matters for planning the rest of the setup, because the emulator system image
is several gigabytes and comes from the slower portal. It is the largest single item on the
critical path.

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
| 4 | `node scripts/try-engine.mjs --mock` | remote answers, redaction counted, offline fallback shown |
| 5 | `scripts/setup-toolchain.sh` | `devecocli` 1.3.4 and DevEco Studio found |
| 6 | `devecocli device list` | the emulator appears |
| 7 | `scripts/dev-loop.sh build` | `BUILD SUCCESSFUL` and a `.hap` on disk |
| 8 | `scripts/dev-loop.sh run` | the app installs and launches |
| 9 | `scripts/enable-ime.sh --status` | Bridge listed and current |
| 10 | `scripts/dev-loop.sh logs` | `inputStart: editor attached` |

Step 10 is the real milestone: it means the keyboard is attached to another application's text
field, which is the claim the whole submission rests on.

Steps 1 to 4 need no SDK and no device, so they can be run on a clean checkout immediately.

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
