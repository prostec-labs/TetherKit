// TetherKitLoaderApp.swift
// TetherKit Loader — macOS host application
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

@main
struct TetherKitLoaderApp: App {

    // The SystemExtensionManager is an ObservableObject; we hold one
    // instance for the full app lifetime and inject it into the environment.
    @StateObject private var extensionManager = SystemExtensionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(extensionManager)
                // Fixed comfortable size — not user-resizable for this utility.
                .frame(minWidth: 480, idealWidth: 520,
                       minHeight: 360, idealHeight: 400)
        }
        .windowResizability(.contentSize)
        .commands {
            // Remove the default New Window command — single-window app.
            CommandGroup(replacing: .newItem) {}
        }
    }
}
