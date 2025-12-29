import SwiftUI

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
                let gridColumns = min(columns, sessionStore.sessions.count)
                let gridRows = (sessionStore.sessions.count + gridColumns - 1) / gridColumns

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
    @State private var terminalOutput: String = ""
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

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
                        restartSession()
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

            // Terminal content
            ScrollViewReader { proxy in
                ScrollView {
                    Text(terminalOutput)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("terminal-bottom")
                }
                .onChange(of: terminalOutput) { _, _ in
                    proxy.scrollTo("terminal-bottom", anchor: .bottom)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // Input field
            HStack {
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isFocused)
                    .onSubmit {
                        sendInput()
                    }

                Button(action: sendInput) {
                    Image(systemName: "arrow.up.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            sessionStore.activeSessionId = session.id
            isFocused = true
        }
        .onAppear {
            setupTerminal()
        }
    }

    private func setupTerminal() {
        if let process = sessionStore.getTerminalProcess(session.id) {
            process.onOutput = { output in
                terminalOutput += output
            }
        } else {
            sessionStore.startSession(session.id)
            if let process = sessionStore.getTerminalProcess(session.id) {
                process.onOutput = { output in
                    terminalOutput += output
                }
            }
        }
    }

    private func sendInput() {
        guard !inputText.isEmpty else { return }
        sessionStore.sendInput(session.id, text: inputText + "\n")
        terminalOutput += "> \(inputText)\n"
        inputText = ""
    }

    private func restartSession() {
        terminalOutput = ""
        sessionStore.startSession(session.id)
        setupTerminal()
    }
}

#Preview {
    SessionGridView()
        .environmentObject(SessionStore())
}
