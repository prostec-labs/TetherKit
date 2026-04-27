// ContentView.swift
// Main UI for TetherKit Loader
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

import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var extensionManager: SystemExtensionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ------------------------------------------------------------------
            // Header
            // ------------------------------------------------------------------
            HStack(spacing: 12) {
                Image(systemName: "phone.connection")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TetherKit")
                        .font(.title2.bold())
                    Text("Android USB Tethering Driver")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Plug in your Android phone → enable USB tethering → get internet on your Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Status badge
                statusBadge
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // ------------------------------------------------------------------
            // Action buttons
            // ------------------------------------------------------------------
            HStack(spacing: 12) {
                Button {
                    extensionManager.installDriver()
                } label: {
                    Label("Install Driver", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!extensionManager.canInstall)
                .help("Install and activate the TetherKit driver extension.")

                Button {
                    extensionManager.uninstallDriver()
                } label: {
                    Label("Uninstall Driver", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!extensionManager.canUninstall)
                .help("Deactivate and remove the TetherKit driver extension.")

                Button {
                    extensionManager.refreshStatus()
                } label: {
                    Label("Refresh Status", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(extensionManager.isBusy)
                .help("Refresh the displayed driver status.")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // ------------------------------------------------------------------
            // Log / status area
            // ------------------------------------------------------------------
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Activity Log")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Button {
                        extensionManager.clearLog()
                    } label: {
                        Text("Clear")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.bottom, 2)

                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(extensionManager.statusLines) { line in
                                Text(line.text)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.primary.opacity(0.85))
                                    .textSelection(.enabled)
                                    .id(line.id)
                            }
                        }
                        .padding(8)
                    }
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: extensionManager.statusLines.count) { _ in
                        withAnimation {
                            if let lastId = extensionManager.statusLines.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // ------------------------------------------------------------------
            // Footer
            // ------------------------------------------------------------------
            HStack {
                if extensionManager.isBusy {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(height: 14)
                }
                Text(footerText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Link("Developer Docs",
                     destination: URL(string: "https://developer.apple.com/documentation/driverkit")!)
                    .font(.caption)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    // MARK: - Sub-views

    private var statusBadge: some View {
        Group {
            if extensionManager.isBusy {
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.7)
                    Text("Working…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(extensionManager.driverState.badgeLabel)
                        .font(.caption.bold())
                        .foregroundColor(statusColor)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary)
        .clipShape(Capsule())
    }

    private var footerText: String {
        if extensionManager.isBusy {
            return "After approving, check System Settings → Privacy & Security."
        }
        return extensionManager.driverState.summary
    }

    private var statusColor: Color {
        switch extensionManager.driverState {
        case .installed:
            return .green
        case .waitingForApproval, .pendingInstallAfterReboot, .pendingUninstallAfterReboot:
            return .orange
        case .unknown:
            return .secondary
        case .notInstalled:
            return .red
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SystemExtensionManager())
            .frame(width: 520, height: 400)
    }
}
