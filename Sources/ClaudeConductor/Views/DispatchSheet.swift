import SwiftUI

struct DispatchSheet: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) var dismiss

    @State private var prompt = ""
    @State private var selectedWorkers: Set<UUID> = []
    @State private var broadcastToAll = true

    var body: some View {
        VStack(spacing: 20) {
            Text("Dispatch Task")
                .font(.title2)
                .fontWeight(.semibold)

            // Prompt input
            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt")
                    .font(.headline)

                TextEditor(text: $prompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
            }

            Divider()

            // Target selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Target")
                    .font(.headline)

                Toggle("Broadcast to all workers", isOn: $broadcastToAll)

                if !broadcastToAll {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select workers:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ForEach(sessionStore.workerSessions) { session in
                            HStack {
                                Image(systemName: selectedWorkers.contains(session.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedWorkers.contains(session.id) ? .accentColor : .secondary)

                                Image(systemName: session.role.icon)
                                    .foregroundColor(session.role.color)

                                Text(session.name)

                                Spacer()

                                Circle()
                                    .fill(session.status.color)
                                    .frame(width: 8, height: 8)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedWorkers.contains(session.id) {
                                    selectedWorkers.remove(session.id)
                                } else {
                                    selectedWorkers.insert(session.id)
                                }
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }
            }

            // Quick prompts
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Prompts")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        QuickPromptButton(title: "Status Check", prompt: "What are you currently working on? Give me a brief status update.") { p in
                            prompt = p
                        }

                        QuickPromptButton(title: "Continue", prompt: "Continue with your current task.") { p in
                            prompt = p
                        }

                        QuickPromptButton(title: "Pause", prompt: "Pause your current work and wait for further instructions.") { p in
                            prompt = p
                        }

                        QuickPromptButton(title: "Summarize", prompt: "Summarize what you've accomplished so far.") { p in
                            prompt = p
                        }
                    }
                }
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Dispatch") {
                    dispatch()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(prompt.isEmpty || (!broadcastToAll && selectedWorkers.isEmpty))
            }
        }
        .frame(width: 500)
        .padding()
        .onAppear {
            // Pre-select active session if any
            if let activeId = sessionStore.activeSessionId,
               sessionStore.workerSessions.contains(where: { $0.id == activeId }) {
                selectedWorkers.insert(activeId)
                broadcastToAll = false
            }
        }
    }

    private func dispatch() {
        if broadcastToAll {
            sessionStore.dispatchToAllWorkers(prompt: prompt)
        } else {
            for workerId in selectedWorkers {
                let task = DispatchTask(targetSessionId: workerId, prompt: prompt)
                sessionStore.dispatchTask(task)
            }
        }
        dismiss()
    }
}

struct QuickPromptButton: View {
    let title: String
    let prompt: String
    let action: (String) -> Void

    var body: some View {
        Button(action: { action(prompt) }) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DispatchSheet()
        .environmentObject(SessionStore())
}
