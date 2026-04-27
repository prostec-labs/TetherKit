// SystemExtensionManager.swift
// Manages activation and deactivation of the TetherKitDriver system extension.
// TetherKit Loader
//
//   Copyright (c) 2012 Joshua Wise.
//   Copyright (c) 2018 Mikhail Iakhiaev
//
// Ported to DriverKit by Prostec Labs, 2026.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.

import Foundation
import SystemExtensions
import os.log

/// A single timestamped line in the activity log.
struct LogLine: Identifiable {
    let id: Int
    let text: String
}

enum DriverState: Equatable {
    case unknown
    case notInstalled
    case waitingForApproval
    case installed
    case pendingInstallAfterReboot
    case pendingUninstallAfterReboot

    var badgeLabel: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .notInstalled:
            return "Not installed"
        case .waitingForApproval:
            return "Needs approval"
        case .installed:
            return "Active"
        case .pendingInstallAfterReboot:
            return "Reboot to finish install"
        case .pendingUninstallAfterReboot:
            return "Reboot to finish removal"
        }
    }

    var summary: String {
        switch self {
        case .unknown:
            return "Status is unknown until this app performs an install or uninstall request."
        case .notInstalled:
            return "Driver is not installed."
        case .waitingForApproval:
            return "Waiting for approval in System Settings."
        case .installed:
            return "Driver is installed and active."
        case .pendingInstallAfterReboot:
            return "Installation will complete after reboot."
        case .pendingUninstallAfterReboot:
            return "Removal will complete after reboot."
        }
    }
}

/// Manages the lifecycle of the TetherKitDriver DriverKit system extension.
///
/// This class implements `OSSystemExtensionRequestDelegate` and posts status
/// updates via `@Published` properties so SwiftUI views can react to changes.
///
/// Deployment model (mirrors the ASIX/Plugable AX88179 pattern):
///   - The .dext bundle lives inside this app at
///       Contents/Library/SystemExtensions/com.prostec.tetherkit.driver.dext
///   - On "Install Driver", we submit an `OSSystemExtensionRequest` for
///       activation. macOS copies the dext to the system location and prompts
///       the user in System Settings -> Privacy & Security.
///   - This loader app must remain installed (though not necessarily running)
///       for macOS to keep the dext active. Uninstalling this app silently
///       deactivates the dext on next reboot.
///   - On "Uninstall Driver", we submit a deactivation request.
final class SystemExtensionManager: NSObject, ObservableObject {

    // MARK: - Public state

    /// Timestamped log lines shown in the UI activity log.
    @Published var statusLines: [LogLine] = [LogLine(id: 0, text: "Ready.")]

    /// Whether an install or uninstall request is in flight.
    @Published var isBusy: Bool = false

    /// Current user-visible state of the system extension.
    @Published private(set) var driverState: DriverState = .unknown

    // MARK: - Private

    private let log = Logger(subsystem: "com.prostec.tetherkit.loader",
                             category: "SystemExtensionManager")

    /// Bundle identifier of the dext - must match IOUserServerName in Info.plist
    /// and the embedded dext bundle at Contents/Library/SystemExtensions/.
    static let driverIdentifier = "com.prostec.tetherkit.driver"

    private enum PendingOperation { case install, uninstall }
    private var pendingOperation: PendingOperation?
    private var stateBeforeRequest: DriverState = .unknown
    private var nextLineId: Int = 1

    var isInstalled: Bool {
        driverState == .installed || driverState == .pendingUninstallAfterReboot
    }

    var canInstall: Bool {
        !isBusy && driverState != .installed && driverState != .waitingForApproval
            && driverState != .pendingInstallAfterReboot
    }

    var canUninstall: Bool {
        !isBusy && driverState != .notInstalled && driverState != .pendingUninstallAfterReboot
    }

    // MARK: - Public API

    /// Clear the activity log.
    func clearLog() {
        let line = LogLine(id: nextLineId, text: "Log cleared.")
        nextLineId += 1
        statusLines = [line]
    }

    /// Submit an activation (install) request for the driver extension.
    func installDriver() {
        guard !isBusy else { return }
        isBusy = true
        pendingOperation = .install
        stateBeforeRequest = driverState
        driverState = .waitingForApproval
        appendStatus("Requesting driver activation...")
        log.info("Submitting activation request for \(Self.driverIdentifier)")

        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: Self.driverIdentifier,
            queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    /// Submit a deactivation (uninstall) request for the driver extension.
    func uninstallDriver() {
        guard !isBusy else { return }
        isBusy = true
        pendingOperation = .uninstall
        stateBeforeRequest = driverState
        appendStatus("Requesting driver deactivation...")
        log.info("Submitting deactivation request for \(Self.driverIdentifier)")

        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: Self.driverIdentifier,
            queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    /// Refresh the displayed status string. Because OSSystemExtension does
    /// not offer a live query API we can only echo the last known state.
    func refreshStatus() {
        appendStatus("Status: \(driverState.summary)")
        appendStatus("Note: macOS does not expose a direct polling API for system extension activation state.")
    }

    // MARK: - Helpers

    private func appendStatus(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(),
                                                     dateStyle: .none,
                                                     timeStyle: .medium)
        let line = LogLine(id: nextLineId, text: "[\(timestamp)] \(message)")
        nextLineId += 1
        DispatchQueue.main.async {
            self.statusLines.append(line)
            // Keep at most 200 lines to avoid unbounded growth.
            if self.statusLines.count > 200 {
                self.statusLines.removeFirst(self.statusLines.count - 200)
            }
        }
        log.info("\(message)")
    }
}

// MARK: - OSSystemExtensionRequestDelegate

extension SystemExtensionManager: OSSystemExtensionRequestDelegate {

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties)
    -> OSSystemExtensionRequest.ReplacementAction
    {
        // Always replace with the newer version embedded in this app bundle.
        appendStatus("Replacing existing driver v\(existing.bundleShortVersion) "
                   + "with v\(ext.bundleShortVersion).")
        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        driverState = .waitingForApproval
        appendStatus("Waiting for user approval in "
                   + "System Settings -> Privacy & Security -> Allow "
                   + "'\(Self.driverIdentifier)'.")
        appendStatus("Open System Settings and click 'Allow' to continue.")
    }

    func request(_ request: OSSystemExtensionRequest,
                 didFinishWithResult result: OSSystemExtensionRequest.Result)
    {
        defer {
            pendingOperation = nil
            stateBeforeRequest = driverState
        }
        isBusy = false
        switch result {
        case .completed:
            if pendingOperation == .install {
                driverState = .installed
                appendStatus("Driver installed successfully. "
                           + "Connect an Android phone and enable USB tethering.")
            } else {
                driverState = .notInstalled
                appendStatus("Driver uninstalled. Reconnect the phone to verify.")
            }

        case .willCompleteAfterReboot:
            if pendingOperation == .install {
                driverState = .pendingInstallAfterReboot
            } else {
                driverState = .pendingUninstallAfterReboot
            }
            appendStatus("Change will take effect after reboot.")

        @unknown default:
            driverState = .unknown
            appendStatus("Request completed with unknown result.")
        }
    }

    func request(_ request: OSSystemExtensionRequest,
                 didFailWithError error: Error)
    {
        defer {
            pendingOperation = nil
            stateBeforeRequest = driverState
        }
        isBusy = false
        if case .waitingForApproval = driverState {
            driverState = stateBeforeRequest
        }
        let nsErr = error as NSError
        appendStatus("Request failed: \(nsErr.localizedDescription) "
                   + "(domain=\(nsErr.domain) code=\(nsErr.code))")

        if nsErr.domain == OSSystemExtensionErrorDomain {
            switch OSSystemExtensionError.Code(rawValue: nsErr.code) {
            case .unsupportedParentBundleLocation:
                appendStatus("Hint: the app must be run from /Applications - "
                           + "move it out of Downloads / DMG and try again.")
            case .extensionNotFound:
                appendStatus("Hint: the .dext bundle was not found inside "
                           + "this app. Re-install the application.")
            case .authorizationRequired:
                appendStatus("Hint: re-run with administrator privileges, or "
                           + "approve the extension in System Settings.")
            case .requestSuperseded:
                appendStatus("Hint: a previous identical request is already pending.")
            default:
                break
            }
        }
        log.error("Extension request failed: \(error.localizedDescription)")
    }
}
