import SwiftUI

struct SettingsView: View {
    @AppStorage("claudeCommand") private var claudeCommand = "claude"
    @AppStorage("defaultMCPPort") private var defaultMCPPort = 55557
    @AppStorage("autoStartSessions") private var autoStartSessions = true

    var body: some View {
        Form {
            Section("Claude Code") {
                TextField("Claude Command", text: $claudeCommand)
                    .textFieldStyle(.roundedBorder)

                Text("Path to claude executable or just 'claude' if in PATH")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("MCP Configuration") {
                Stepper("Default MCP Port: \(defaultMCPPort)", value: $defaultMCPPort, in: 55500...55700)

                Text("Starting port for new sessions. Each session will increment from here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Behavior") {
                Toggle("Auto-start sessions on creation", isOn: $autoStartSessions)
            }

            Section("Presets") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default session presets can be configured in the New Session sheet.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Reset All Settings") {
                        claudeCommand = "claude"
                        defaultMCPPort = 55557
                        autoStartSessions = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 350)
        .padding()
    }
}

#Preview {
    SettingsView()
}
