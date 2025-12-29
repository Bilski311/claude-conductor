import Foundation
import SwiftUI
import Combine

/// Main state management for all Claude sessions
@MainActor
class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var activeSessionId: UUID?
    @Published var showNewSessionSheet = false
    @Published var showDispatchSheet = false
    @Published var taskHistory: [DispatchTask] = []

    private var terminalProcesses: [UUID: TerminalProcess] = [:]

    init() {
        // Create a default session for demo
        #if DEBUG
        let demoSession = Session(
            name: "Main",
            directory: "/Users/dominikbilski/private/Metanoia",
            mcpPort: 55557,
            role: .conductor
        )
        sessions.append(demoSession)
        activeSessionId = demoSession.id
        #endif
    }

    var conductorSession: Session? {
        sessions.first { $0.role == .conductor }
    }

    var workerSessions: [Session] {
        sessions.filter { $0.role == .worker }
    }

    var activeSession: Session? {
        guard let id = activeSessionId else { return nil }
        return sessions.first { $0.id == id }
    }

    // MARK: - Session Management

    func addSession(_ session: Session) {
        sessions.append(session)
        if activeSessionId == nil {
            activeSessionId = session.id
        }
    }

    func removeSession(_ id: UUID) {
        // Stop the terminal process
        if let process = terminalProcesses[id] {
            process.terminate()
            terminalProcesses.removeValue(forKey: id)
        }
        sessions.removeAll { $0.id == id }
        if activeSessionId == id {
            activeSessionId = sessions.first?.id
        }
    }

    func updateSessionStatus(_ id: UUID, status: SessionStatus) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].status = status
        }
    }

    // MARK: - Terminal Process Management

    func startSession(_ id: UUID) {
        guard let session = sessions.first(where: { $0.id == id }) else { return }

        let process = TerminalProcess(
            directory: session.directory,
            environment: ["MCP_UE_PORT": "\(session.mcpPort)"]
        )

        process.onOutput = { [weak self] output in
            // Handle terminal output
            self?.handleTerminalOutput(sessionId: id, output: output)
        }

        process.onStatusChange = { [weak self] isRunning in
            Task { @MainActor in
                self?.updateSessionStatus(id, status: isRunning ? .working : .disconnected)
            }
        }

        terminalProcesses[id] = process
        process.start(command: "claude")
        updateSessionStatus(id, status: .working)
    }

    func sendInput(_ id: UUID, text: String) {
        terminalProcesses[id]?.sendInput(text)
    }

    func getTerminalProcess(_ id: UUID) -> TerminalProcess? {
        terminalProcesses[id]
    }

    // MARK: - Orchestration

    func dispatchTask(_ task: DispatchTask) {
        taskHistory.append(task)

        // Send the prompt to the target session
        if let process = terminalProcesses[task.targetSessionId] {
            process.sendInput(task.prompt + "\n")
            updateSessionStatus(task.targetSessionId, status: .working)
        }
    }

    func dispatchToAllWorkers(prompt: String) {
        for session in workerSessions {
            let task = DispatchTask(targetSessionId: session.id, prompt: prompt)
            dispatchTask(task)
        }
    }

    // MARK: - Private

    private func handleTerminalOutput(sessionId: UUID, output: String) {
        // Detect status changes based on output
        // e.g., if output contains ">" prompt, session is waiting for input
        if output.contains("> ") || output.contains("❯ ") {
            Task { @MainActor in
                updateSessionStatus(sessionId, status: .waitingForInput)
            }
        }
    }
}
