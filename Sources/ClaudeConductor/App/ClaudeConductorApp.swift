import SwiftUI
import AppKit

@main
struct ClaudeConductorApp: App {
    @StateObject private var sessionStore = SessionStore()

    init() {
        // Make the app a regular app (not accessory/background)
        NSApplication.shared.setActivationPolicy(.regular)
        // Activate and bring to front
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .onAppear {
                    // Ensure window comes to front
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Session") {
                    sessionStore.showNewSessionSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Dispatch Task") {
                    sessionStore.showDispatchSheet = true
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(sessionStore)
        }
    }
}
