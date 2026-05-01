# BUILD_NOTES.md — TetherKit
## Step-by-step guide for the Prostec Labs developer

This document supplements the README with concrete Xcode steps, signing details,
and distribution guidance. Read it top-to-bottom the first time you build.

---

## 0. Before You Open Xcode

### 0.1 Set your Team ID

Open `Configs/Shared.xcconfig` in any text editor:

```
DEVELOPMENT_TEAM = AB12CD34EF   ← replace with your Team ID
```

Your Team ID is at https://developer.apple.com/account → Membership → Team ID.

### 0.2 Request DriverKit entitlements from Apple (if not already done)

The two entitlements below require Apple approval before they will work in a
production-signed build (outside of local developer mode):

| Entitlement | Purpose |
|---|---|
| `com.apple.developer.driverkit` | Core DriverKit — required for any dext |
| `com.apple.developer.driverkit.family.networking` | IOUserNetworkEthernet |

Submit the request at:
**https://developer.apple.com/contact/request/system-extension/**

Select "DriverKit" and describe the use case: "RNDIS USB tethering from Android
devices over USB. The driver uses IOUSBHostInterface + IOUserNetworkEthernet
to provide network tethering without a kernel extension."

Allow 1–2 weeks for Apple's response. Once approved, the entitlements appear in
your provisioning profiles automatically.

The `com.apple.developer.driverkit.transport.usb` entitlement does not require
separate approval — it is covered by the general DriverKit approval.

---

## 1. Open the Project

```
File → Open → TetherKit.xcodeproj
```

Xcode 15 will prompt to resolve packages — there are none; dismiss the dialog.

You will see three targets in the scheme selector:
- **TetherKitLoader** — the macOS app
- **TetherKitDriver** — the DriverKit extension
- **TetherKitDriverTests** — XCTest stub

---

## 2. Build the dext Target First

Before building the full app, verify the DriverKit code compiles cleanly.

1. Select scheme: **TetherKitDriver**
2. Destination: **My Mac**
3. Product → **Build** (⌘B)

This invokes the IIG compiler on `TetherKitDriver.iig`, generating
`TetherKitDriver.h` in `$(DERIVED_SOURCES_DIR)`, then compiles `TetherKitDriver.cpp`
against DriverKit headers. Expect a clean build.

**Common first-build errors and fixes:**

| Error | Cause | Fix |
|---|---|---|
| `IIG not found` | Xcode < 15 | Upgrade to Xcode 15+ |
| `NetworkingDriverKit/IOUserNetworkEthernet.iig not found` | Wrong SDK | Confirm SDKROOT = driverkit in target build settings |
| `'IOLib.h' file not found (IOKit path)` | IOKit header included | Never `#include <IOKit/...>` in dext sources |
| `Code signing error — entitlement not permitted` | Entitlements not yet approved by Apple | Enable developer mode: `systemextensionsctl developer on` |
| `DEVELOPMENT_TEAM is empty` | xcconfig not set | Edit `Configs/Shared.xcconfig` |

---

## 3. Build the Loader App

1. Select scheme: **TetherKitLoader**
2. Destination: **My Mac**
3. Product → **Build** (⌘B)

The loader app build depends on the driver target. Xcode will build the dext
first, then embed it into the app bundle at:

```
TetherKitLoader.app/Contents/Library/SystemExtensions/TetherKitDriver.dext
```

Verify the embedding with:
```bash
ls "$(xcodebuild -showBuildSettings | grep BUILT_PRODUCTS_DIR | awk '{print $3}')/TetherKitLoader.app/Contents/Library/SystemExtensions/"
# Should show: TetherKitDriver.dext
```

---

## 4. Enable Developer Mode and Test Locally

```bash
# Enable developer mode (persists only until next reboot)
systemextensionsctl developer on
```

Then run the app from Xcode (⌘R). Click **Install Driver**. macOS will prompt
in System Settings → Privacy & Security. Click **Allow**.

Connect an Android phone, enable USB tethering, and verify:
```bash
ifconfig -a        # Look for a new enX interface
ping -c3 8.8.8.8  # Test connectivity through the tethered link
```

---

## 5. Sign and Notarize for Distribution

### 5.1 Create an archive

1. Select scheme **TetherKitLoader**, destination **Any Mac**.
2. Product → **Archive**.
3. In the Organizer, select the archive → **Distribute App**.

### 5.2 Choose distribution method

- **Developer ID Application** — for direct download outside the App Store.
  This requires Developer ID signing and notarization. Recommended for Prostec Labs.
- **App Store Connect** — for Mac App Store. Note: the App Store route for dexts
  requires additional Apple review and is less common for driver software.

### 5.3 Notarize

Xcode's Organizer handles notarization automatically when "Distribute App →
Developer ID" is selected. Ensure your Apple ID and app-specific password are
configured in Xcode Preferences → Accounts.

Alternatively, use the command line:
```bash
xcrun notarytool submit TetherKitLoader.zip \
  --apple-id you@prostec.ai \
  --password "@keychain:AC_PASSWORD" \
  --team-id AB12CD34EF \
  --wait
```

### 5.4 Staple the notarization ticket

```bash
xcrun stapler staple TetherKitLoader.app
```

---

## 6. Distribution Model — Following the ASIX/Plugable Pattern

This project's shipping shape is modelled directly on the ASIX AX88179 DriverKit
dext as deployed by Plugable in their USB3-E1000 / USBC-E1000 adapters
(v2.4.0+, macOS 12–14).

**Reference:** https://kb.plugable.com/wired-network-adapters/asix-dext-ethernet-driver-in-macos-11x-big-sur-and-macos-12x-monterey

### What this means for Prostec Labs:

1. **Single installer app.** The dext lives inside `TetherKitLoader.app` at
   `Contents/Library/SystemExtensions/TetherKitDriver.dext`. Users download and
   install the app; there is no separate `.pkg` or `.dmg` for the driver itself.

2. **One-time user approval.** At first launch, the app calls
   `OSSystemExtensionRequest` for activation. macOS shows a prompt in
   System Settings → Privacy & Security. The user clicks **Allow** once.
   This is identical to the Plugable experience.

3. **The loader app must remain installed** for the dext to stay active. This is
   a macOS architectural requirement, not a limitation of this implementation.
   If the user deletes `TetherKitLoader.app`, the dext is orphaned and will be
   deactivated on the next reboot. The Plugable documentation for AX88179 v2.4.0
   explicitly states this. **Inform end users accordingly.**

4. **The loader app does not need to be running.** Only the initial installation
   requires the app to be open. After approval, the dext loads automatically
   whenever a matching USB device is connected, even if the loader app is quit.

5. **Updates.** Ship a new version of the app bundle with an incremented
   `CFBundleVersion`. On next launch, `OSSystemExtensionRequest` with
   `actionForReplacingExtension` returning `.replace` handles the upgrade.

6. **Uninstallation.** Clicking "Uninstall Driver" in the app calls the
   deactivation request. The dext is removed from the system. The app itself
   can then be dragged to Trash.

### Key difference from the kext era

The original HoRNDIS kext required the user to disable SIP and manually load
the kext via `kextload`. This dext ships entirely within the SIP boundary —
no SIP disabling is needed by end users, and the macOS notarization + System
Extension approval model ensures the driver is trusted by Gatekeeper.

---

## 7. Debugging in Production

### Log stream

```bash
log stream \
  --predicate 'subsystem == "com.prostec.tetherkit"' \
  --level debug
```

### Check dext status

```bash
systemextensionsctl list
```

### Force-reset a stuck extension

```bash
systemextensionsctl reset   # Resets all pending extension state (requires SIP off)
```

### Collect a sysdiagnose for Apple DTS

```bash
sudo sysdiagnose -f ~/Desktop
```

---

## 8. IIG Build Rule Reference

The IIG compiler is invoked automatically by Xcode when it encounters `.iig`
files in a DriverKit target's Sources phase. The key build settings are:

| Setting | Value | Purpose |
|---|---|---|
| `SDKROOT` | `driverkit` | Selects the DriverKit SDK, not macosx |
| `DRIVERKIT_DEPLOYMENT_TARGET` | `22.0` | macOS 13 Ventura DriverKit runtime |
| `IIG_HEADERS_DIR` | `$(DERIVED_SOURCES_DIR)` | Where IIG writes the generated `.h` |
| `WRAPPER_EXTENSION` | `dext` | Product output is `.dext`, not `.bundle` |
| `GENERATE_INFOPLIST_FILE` | `NO` | We supply `TetherKitDriver/Info.plist` manually |

The IIG compiler generates two files from `TetherKitDriver.iig`:
- `TetherKitDriver.h` — included by `TetherKitDriver.cpp`
- `TetherKitDriver.iig.h` — internal dispatch tables; do not include directly

If you add new virtual methods to the IIG file, run **Product → Clean Build
Folder** before rebuilding to ensure stale generated headers are removed.

---

## 9. Adding Support for Additional RNDIS Devices

To add a new USB device variant:

1. Add a new entry to `TetherKitDriver/Info.plist` under `IOKitPersonalities`.
2. Add a corresponding entry to the `com.apple.developer.driverkit.transport.usb`
   array in `TetherKitDriver/TetherKitDriver.entitlements`.
3. If the new device requires a different RNDIS initialisation sequence, extend
   `rndisInit()` in `TetherKitDriver.cpp`.
4. Submit an updated entitlement request to Apple if the new USB class/subclass/
   protocol values are outside those already approved.

---

## 10. Streaming dext logs

DriverKit doesn't expose `os_log_create()`, so the dext logs to `OS_LOG_DEFAULT`
and tags every line with `[TetherKit][<category>]`. Filter live by the dext's
bundle id (which unified logging attaches as the `process` field):

```sh
log stream --predicate 'process == "com.prostec.tetherkit.driver"'
```

To watch only error lines:

```sh
log stream --predicate 'process == "com.prostec.tetherkit.driver" \
                       && eventMessage CONTAINS "[error]"'
```

Replay historical logs (last 5 minutes):

```sh
log show --last 5m --predicate 'process == "com.prostec.tetherkit.driver"'
```

---

## Running the protocol unit tests

The `TetherKitProtocolTests` target compiles `RNDISProtocolCore.{h,cpp}`
and `TetherKitProtocolTests.mm` against the `macosx` SDK with no
DriverKit dependency. Run from the repo root:

```sh
xcodebuild test -project TetherKit.xcodeproj -scheme TetherKitDriver \
  -destination 'platform=macOS' \
  -only-testing:TetherKitProtocolTests \
  CODE_SIGNING_ALLOWED=NO
```

These tests do NOT need a connected device, an installed dext, or
DriverKit entitlements. They exercise the wire-format math: struct
sizes, multi-packet inbound coalescing, max_transfer_size clamping,
and the multicast-bit MAC fixup.
