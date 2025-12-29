import SwiftUI

@main
struct ClaudeConductorApp: App {
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
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
