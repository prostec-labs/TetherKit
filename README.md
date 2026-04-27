# TetherKit 🤖🔌🖥️

**Share your Android phone's mobile internet with your Mac over USB — no Wi-Fi needed.**

Plug in your Android phone, enable USB tethering in your phone's settings, and your Mac gets internet through the phone's connection. TetherKit is the macOS driver that makes this work.

> **Technical:** TetherKit is a DriverKit (dext) port of [HoRNDIS](https://github.com/jwise/HoRNDIS), an RNDIS USB tethering driver for macOS 13 Ventura and later. It replaces the legacy kernel extension with a fully user-space driver that works without disabling SIP.

A free [Mac App Store](https://apps.apple.com) release by [Prostec Labs](https://prostec.ai) is coming — no SIP changes, no manual installs.

---

## After Cloning

Run these three commands before anything else:

```bash
# 1. Activate the pre-commit hook (blocks accidental secret commits)
git config core.hooksPath .githooks

# 2. Set your Apple Developer Team ID (never committed — local only)
#    Find it at https://developer.apple.com/account → Membership → Team ID
#    Open Configs/Shared.xcconfig and fill in the blank line:
#      DEVELOPMENT_TEAM = YOUR10CHARID

# 3. Enable DriverKit developer mode (required to load the dext locally)
systemextensionsctl developer on
```

Then open `TetherKit.xcodeproj` and build the `TetherKitDriver` scheme.

---

## Table of Contents

1. [Project Layout](#project-layout)
2. [Prerequisites](#prerequisites)
3. [Setup — Team ID](#setup--team-id)
4. [Development Setup (SIP / developer mode)](#development-setup-sip--developer-mode)
5. [Build Instructions](#build-instructions)
6. [Install / Uninstall](#install--uninstall)
7. [Debugging](#debugging)
8. [Known Limitations](#known-limitations)
9. [Reference & Acknowledgements](#reference--acknowledgements)
10. [Security](#security)
11. [License](#license)

---

## Project Layout

```
TetherKit/
├── TetherKit.xcodeproj/    Xcode project (three targets)
│   └── project.pbxproj
│
├── Configs/
│   └── Shared.xcconfig             ← SET DEVELOPMENT_TEAM HERE
│
├── TetherKitLoader/                  Target 1: macOS SwiftUI app (deployment 13.0)
│   ├── TetherKitLoaderApp.swift      @main App entry point
│   ├── ContentView.swift           Install / Uninstall / Status UI
│   ├── SystemExtensionManager.swift OSSystemExtensionRequest delegate
│   ├── Info.plist
│   └── TetherKitLoader.entitlements  com.apple.developer.system-extension.install
│
├── TetherKitDriver/                  Target 2: DriverKit dext (SDK driverkit 22.0+)
│   ├── TetherKitDriver.iig           IIG interface — extends IOUserNetworkEthernet
│   ├── TetherKitDriver.cpp           Implementation (USB open, RNDIS init, bulk I/O)
│   ├── RNDISProtocol.h             RNDIS structs, OIDs, constants (ported from kext)
│   ├── Info.plist                  IOKitPersonalities for three RNDIS variants
│   └── TetherKitDriver.entitlements  driverkit + networking family + transport.usb
│
└── TetherKitDriverTests/             Target 3: XCTest stub
    └── TetherKitDriverTests.swift
```

The dext is embedded inside the loader app at:
```
TetherKitLoader.app/Contents/Library/SystemExtensions/TetherKitDriver.dext
```
This is the Apple-required location — identical to the ASIX/Plugable pattern for USB-Ethernet dexts on macOS 12–14.

---

## Prerequisites

| Requirement | Details |
|---|---|
| **Xcode 15+** | DriverKit IIG compiler and NetworkingDriverKit headers are included from Xcode 15 onward |
| **macOS 13 Ventura+** | Deployment target for both the loader app and the dext runtime |
| **Apple Developer account** | Required for code-signing and entitlement provisioning |
| **DriverKit entitlements** | **Must be individually approved by Apple** — see below |
| **DriverKit 22.0 SDK** | Included with Xcode 15 (ships with macOS 13 SDK) |

### Apple Entitlement Approval — Critical

Before the dext will load on any machine (even your own, outside of developer mode), Apple must approve the following entitlements for your App ID:

- `com.apple.developer.driverkit` — required for all dexts
- `com.apple.developer.driverkit.family.networking` — required for IOUserNetworkEthernet
- `com.apple.developer.driverkit.transport.usb` — required for IOUSBHostInterface

**Request form:** https://developer.apple.com/contact/request/system-extension/

Submit a request for both `com.apple.developer.driverkit` and `com.apple.developer.driverkit.family.networking`. Describe the use case (RNDIS USB tethering from Android devices). Apple typically responds within 1–2 weeks.

> **Note:** Without approved entitlements, the dext will be rejected at installation time with a cryptic `OSSystemExtensionErrorDomain` error. Developer mode (below) bypasses this check for local development.

---

## Setup — Team ID

**Before building**, open `Configs/Shared.xcconfig` and set your Team ID:

```
DEVELOPMENT_TEAM = AB12CD34EF   # ← replace with your 10-char Team ID
```

Find your Team ID at https://developer.apple.com/account → Membership → Team ID.

This single setting propagates to both targets. You do not need to touch `project.pbxproj`.

> **Never commit your Team ID.** `Configs/Shared.xcconfig` intentionally ships with `DEVELOPMENT_TEAM =` blank. Set it locally and leave it out of any commits or PRs.

### Pre-commit hook (recommended)

A pre-commit hook is included that blocks accidental commits of Team IDs, provisioning profile UUIDs, and common credential patterns. Activate it once after cloning:

```bash
git config core.hooksPath .githooks
```

---

## Development Setup (SIP / Developer Mode)

During development — before Apple approves your entitlements — you can test on your own machine using DriverKit developer mode.

### Step 1 — Enable Developer Mode

```bash
systemextensionsctl developer on
```

This disables entitlement checks for system extensions on the local machine. You must re-run this after each reboot (it does not persist across reboots by design).

### Step 2 — Verify SIP Status

```bash
csrutil status
```

Developer mode is usually sufficient. Full SIP disable is **not** required for dexts on macOS 13+, but if you encounter kernel panics or unexplained load failures during early development, you can disable SIP:

1. Boot into Recovery (`Command + R` at startup on Intel; hold power button on Apple Silicon).
2. In Terminal: `csrutil disable`
3. Reboot.

Re-enable SIP (`csrutil enable`) when finished developing — shipping a dext never requires SIP disabled on end-user machines.

### Step 3 — Build and Run from Xcode

Always run the TetherKitLoader app from `/Applications` or the Xcode-built products folder. Running from a DMG or Downloads will trigger `OSSystemExtensionErrorDomain.unsupportedParentBundleLocation`.

---

## Build Instructions

```bash
# Clone / open the project
open TetherKit.xcodeproj

# Or build from the command line (substitute your DEVELOPMENT_TEAM):
xcodebuild \
  -project TetherKit.xcodeproj \
  -scheme TetherKitLoader \
  -configuration Debug \
  DEVELOPMENT_TEAM=AB12CD34EF \
  build
```

**Build the dext target first** to catch any DriverKit compilation errors before building the full app:

```bash
xcodebuild \
  -project TetherKit.xcodeproj \
  -target TetherKitDriver \
  -configuration Debug \
  DEVELOPMENT_TEAM=AB12CD34EF \
  build
```

---

## Install / Uninstall

1. **Build and archive** the TetherKitLoader scheme in Xcode (Product → Archive).
2. **Copy the app** to `/Applications/TetherKitLoader.app`.
3. **Launch** TetherKitLoader.
4. Click **Install Driver**.
5. macOS will prompt in **System Settings → Privacy & Security** — click **Allow**.
6. Connect an Android phone, enable **Settings → Connected Devices → USB tethering**.
7. A new network interface (`enX`) should appear in `ifconfig -a` within a few seconds.

**To uninstall:** Click **Uninstall Driver** in the app, or:

```bash
systemextensionsctl uninstall com.prostec.tetherkit.loader com.prostec.tetherkit.driver
```

> **Deployment note:** The loader app must remain installed (not necessarily running) for macOS to keep the dext active. This matches the ASIX/Plugable AX88179 v2.4.0 shipping pattern — see [Reference & Acknowledgements](#reference--acknowledgements). If the user deletes the loader app, the dext will be deactivated on the next reboot.

---

## Debugging

### Live log stream

```bash
log stream \
  --predicate 'subsystem == "com.prostec.tetherkit"' \
  --level debug
```

### Show all loaded system extensions

```bash
systemextensionsctl list
```

### Check dext activation state

```bash
systemextensionsctl list | grep horndis
```

### USB device introspection

```bash
system_profiler SPUSBDataType | grep -A20 "RNDIS\|Android"
```

### Network interface check

After tethering is active, verify the interface:
```bash
ifconfig -a | grep -A8 "en[0-9]"
networksetup -listallhardwareports
```

### Kernel / dext crash logs

```
~/Library/Logs/DiagnosticReports/TetherKitDriver_*.crash
/Library/Logs/DiagnosticReports/
```

---

## Known Limitations

1. **NetworkingDriverKit supports Ethernet only.** This is correct for RNDIS — it is an Ethernet-over-USB protocol — so this limitation does not affect functionality.

2. **Apple must individually approve the networking family entitlement.** The entitlement `com.apple.developer.driverkit.family.networking` is not automatically granted to all developer accounts. Approval is possible but not guaranteed; Apple evaluates the use case. See the request form link above.

3. **USB composite device matching.** The dext matches on `IOUSBHostInterface`, which requires that another driver has already called `setConfiguration` with `matchInterfaces=true` on the parent USB device. This happens automatically for USB Composite Devices (device class 0/0/0) — which covers all known Android phones. Non-composite RNDIS devices (device class 224/0/0, some Samsung phones) are handled by the WirelessControllerDevice personality in the original kext but are not included here because DriverKit does not easily support the "set configuration, then match children" pattern without a two-stage driver. If Samsung device class 224/0/0 support is needed, a second dext targeting `IOUSBHostDevice` would be required.

4. **No Keep-Alive timer.** The RNDIS specification mandates `REMOTE_NDIS_KEEPALIVE_MSG` polling, but neither the original HoRNDIS nor Android require it. Omitted intentionally; see the `TODO` comment in `TetherKitDriver.cpp`.

5. **No interrupt endpoint polling on the control interface.** Per [MSDN-RNDISUSB], the device should signal response-ready on the interrupt endpoint. Android works fine without it (the polling loop in `rndisCommand()` covers it). A production hardening improvement would gate `rndisCommand` on the interrupt notification.

6. **Single-buffer receive (N_IN_BUFS = 1).** Double-buffering (`N_IN_BUFS = 2`) improved throughput in the original kext but added USB bus contention on half-duplex USB 2.0 links. The original author found single-buffering faster overall. Change `N_IN_BUFS` in `RNDISProtocol.h` to experiment.

7. **macOS 13+ only.** IOUserNetworkEthernet and the `RegisterEthernetInterface` API require DriverKit 22 (macOS 13 Ventura). Earlier macOS versions must continue to use the legacy kext.

---

## Reference & Acknowledgements

### Original HoRNDIS
- **Author:** Joshua Wise, Mikhail Iakhiaev
- **Source:** https://github.com/jwise/HoRNDIS
- **License:** GPLv3
- **Role:** The source of all RNDIS protocol logic — `rndisInit()`, `rndisCommand()`, `rndisQuery()`, `rndisSetPacketFilter()`, packet framing — is adapted from the original kext implementation. The RNDIS struct definitions in `RNDISProtocol.h` are ported verbatim from `HoRNDIS.h`.

### ASIX / Plugable AX88179 DriverKit DEXT
- **Bundle ID:** `com.asix.dext.usbdevice`
- **Reference:** https://kb.plugable.com/wired-network-adapters/asix-dext-ethernet-driver-in-macos-11x-big-sur-and-macos-12x-monterey
- **Role:** Production reference for the USBDriverKit + NetworkingDriverKit shipping pattern on macOS 12–14. The Plugable USB3-E1000 / USBC-E1000 adapters use this dext (v2.4.0+), demonstrating that a USB-Ethernet dext is feasible and approvable by Apple. The deployment shape of this project — an installer app embedding the dext at `Contents/Library/SystemExtensions/`, activated via `OSSystemExtensionRequest`, requiring user approval in System Settings — matches the ASIX/Plugable pattern exactly. Note: ASIX AX88179 uses a vendor-specific wire protocol, not RNDIS; only the DriverKit plumbing pattern is borrowed.

### Apple NetworkingDriverKitSample
- **URL:** https://developer.apple.com/documentation/PCIDriverKit/connecting-a-network-driver
- **Role:** Official Apple sample demonstrating `IOUserNetworkEthernet` + `RegisterEthernetInterface` pattern, packet buffer pool, and transmit/receive queue setup.

### VendorSpecificUSBDriverKitSample (Drewbadour)
- **URL:** https://github.com/Drewbadour/VendorSpecificUSBDriverKitSample
- **Role:** The closest open-source code template for the USB plumbing used in this project. Demonstrates the `IOUSBHostInterface` match, `IOUSBHostPipe.AsyncIO` pattern, and `OSAction` completions — which map directly to the `DataReadComplete` / `DataWriteComplete` callbacks in `TetherKitDriver.cpp`.

### RNDIS Protocol References
- [MS-RNDIS]: Remote Network Driver Interface Specification — https://winprotocoldoc.blob.core.windows.net/productionwindowsarchives/WinArchive/[MS-RNDIS].pdf
- [MSDN-RNDISUSB]: Remote NDIS To USB Mapping — https://docs.microsoft.com/en-us/windows-hardware/drivers/network/remote-ndis-to-usb-mapping
- Linux RNDIS host driver: `linux/drivers/net/usb/rndis_host.c` — Copyright (c) 2005 David Brownell

---

## Security

### Keeping secrets out of git

| What | Where to set it | Never in |
|------|----------------|----------|
| Apple Developer Team ID | `Configs/Shared.xcconfig` (local only) | `project.pbxproj`, any committed file |
| Notarization Apple ID | GitHub Actions secret `APPLE_ID` | Source files or workflow YAML |
| Notarization app password | GitHub Actions secret `APP_PASSWORD` | Source files or workflow YAML |
| Notarization Team ID | GitHub Actions secret `NOTARY_TEAM_ID` | Source files or workflow YAML |

The included pre-commit hook (`.githooks/pre-commit`) catches the most common mistakes. Run `git config core.hooksPath .githooks` once after cloning to activate it.

---

## License

This project is licensed under the **GNU General Public License v3.0** (GPLv3), consistent with the original HoRNDIS from which the RNDIS protocol logic is derived.

```
Copyright (c) 2012 Joshua Wise.
Copyright (c) 2018 Mikhail Iakhiaev
Copyright (c) 2026 Prostec Labs (DriverKit port)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
```

See each source file for the full license header.
