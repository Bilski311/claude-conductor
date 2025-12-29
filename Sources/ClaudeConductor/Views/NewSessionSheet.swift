import SwiftUI

struct NewSessionSheet: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var directory = ""
    @State private var mcpPort = 55557
    @State private var role: SessionRole = .worker

    var body: some View {
        VStack(spacing: 20) {
            Text("New Session")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField("Directory", text: $directory)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse") {
                        browseDirectory()
                    }
                }

                Stepper("MCP Port: \(mcpPort)", value: $mcpPort, in: 55557...55600)

                Picker("Role", selection: $role) {
                    ForEach(SessionRole.allCases, id: \.self) { role in
                        Label(role.rawValue, systemImage: role.icon)
                            .tag(role)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()

            // Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Presets")
                    .font(.headline)

                HStack {
                    PresetButton(
                        title: "Metanoia Worker",
                        directory: "/Users/dominikbilski/private/Metanoia",
                        port: 55558,
                        role: .worker
                    ) { name, dir, port, r in
                        self.name = name
                        self.directory = dir
                        self.mcpPort = port
                        self.role = r
                    }

                    PresetButton(
                        title: "Unreal MCP",
                        directory: "/Users/dominikbilski/private/unreal-mcp",
                        port: 55559,
                        role: .worker
                    ) { name, dir, port, r in
                        self.name = name
                        self.directory = dir
                        self.mcpPort = port
                        self.role = r
                    }

                    PresetButton(
                        title: "Conductor Tools",
                        directory: "/Users/dominikbilski/private/claude-conductor",
                        port: 55560,
                        role: .worker
                    ) { name, dir, port, r in
                        self.name = name
                        self.directory = dir
                        self.mcpPort = port
                        self.role = r
                    }
                }
            }
            .padding()

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    createSession()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || directory.isEmpty)
            }
            .padding()
        }
        .frame(width: 500)
        .padding()
    }

    private func browseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            directory = url.path
            if name.isEmpty {
                name = url.lastPathComponent
            }
        }
    }

    private func createSession() {
        let session = Session(
            name: name,
            directory: directory,
            mcpPort: mcpPort,
            role: role
        )
        sessionStore.addSession(session)
        dismiss()
    }
}

struct PresetButton: View {
    let title: String
    let directory: String
    let port: Int
    let role: SessionRole
    let action: (String, String, Int, SessionRole) -> Void

    var body: some View {
        Button(action: { action(title, directory, port, role) }) {
            VStack(spacing: 4) {
                Image(systemName: role.icon)
                    .foregroundColor(role.color)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NewSessionSheet()
        .environmentObject(SessionStore())
}
