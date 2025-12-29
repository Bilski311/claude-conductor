import SwiftUI
import SwiftTerm
import AppKit

struct SessionGridView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var columns = 2

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(sessionStore.sessions.count) Sessions")
                    .font(.headline)

                Spacer()

                Picker("Layout", selection: $columns) {
                    Image(systemName: "square").tag(1)
                    Image(systemName: "rectangle.split.2x1").tag(2)
                    Image(systemName: "rectangle.split.2x2").tag(4)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Grid of terminal panes
            GeometryReader { geometry in
                let gridColumns = max(1, min(columns, sessionStore.sessions.count))
                let gridRows = max(1, (sessionStore.sessions.count + gridColumns - 1) / gridColumns)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: gridColumns),
                    spacing: 1
                ) {
                    ForEach(sessionStore.sessions) { session in
                        TerminalPaneView(session: session)
                            .frame(
                                minHeight: geometry.size.height / CGFloat(gridRows) - CGFloat(gridRows - 1)
                            )
                    }
                }
            }
        }
    }
}

struct TerminalPaneView: View {
    @EnvironmentObject var sessionStore: SessionStore
    let session: Session

    var isActive: Bool {
        sessionStore.activeSessionId == session.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: session.role.icon)
                    .foregroundColor(session.role.color)

                Text(session.name)
                    .font(.headline)

                Spacer()

                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(session.status.color)
                        .frame(width: 8, height: 8)
                    Text(session.status.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Actions
                Menu {
                    Button("Send Task") {
                        sessionStore.activeSessionId = session.id
                        sessionStore.showDispatchSheet = true
                    }
                    Divider()
                    Button("Restart") {
                        sessionStore.restartSession(session.id)
                    }
                    Button("Close", role: .destructive) {
                        sessionStore.removeSession(session.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
            }
            .padding(8)
            .background(isActive ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))

            Divider()

            // SwiftTerm Terminal View
            SwiftTerminalView(session: session, sessionStore: sessionStore)
                .background(Color.white)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            sessionStore.activeSessionId = session.id
        }
    }
}

// NSViewRepresentable wrapper for SwiftTerm's LocalProcessTerminalView
struct SwiftTerminalView: NSViewRepresentable {
    let session: Session
    let sessionStore: SessionStore

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)

        // Configure terminal appearance - black text on white background
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        terminalView.nativeForegroundColor = NSColor.black
        terminalView.nativeBackgroundColor = NSColor.white

        // Set up environment with proper PATH for Spotlight launches
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["MCP_UE_PORT"] = "\(session.mcpPort)"

        // Ensure common paths are included (for Spotlight launches)
        let additionalPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/Users/\(NSUserName())/.local/bin",
            "/Users/\(NSUserName())/.nvm/versions/node/v22.11.0/bin"
        ]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (additionalPaths + [currentPath]).joined(separator: ":")

        // Start the process - use login shell to source profile
        let shell = env["SHELL"] ?? "/bin/zsh"
        terminalView.startProcess(
            executable: shell,
            args: ["-l", "-i", "-c", "claude"],
            environment: Array(env.map { "\($0.key)=\($0.value)" }),
            execName: "claude"
        )

        // Store reference in session store
        context.coordinator.terminalView = terminalView
        sessionStore.setTerminalView(session.id, view: terminalView)

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        // Updates if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var terminalView: LocalProcessTerminalView?
    }
}

#Preview {
    SessionGridView()
        .environmentObject(SessionStore())
}
