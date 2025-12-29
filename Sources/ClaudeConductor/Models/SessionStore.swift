import Foundation
import SwiftUI
import Combine
import SwiftTerm

/// Main state management for all Claude sessions
@MainActor
class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var activeSessionId: UUID?
    @Published var showNewSessionSheet = false
    @Published var showDispatchSheet = false
    @Published var taskHistory: [DispatchTask] = []

    private var terminalViews: [UUID: LocalProcessTerminalView] = [:]

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
        // The terminal view will be cleaned up when the view is removed
        terminalViews.removeValue(forKey: id)
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

    // MARK: - Terminal View Management

    func setTerminalView(_ id: UUID, view: LocalProcessTerminalView) {
        terminalViews[id] = view
        updateSessionStatus(id, status: .working)
    }

    func getTerminalView(_ id: UUID) -> LocalProcessTerminalView? {
        terminalViews[id]
    }

    func restartSession(_ id: UUID) {
        // Remove terminal view reference - the view will recreate it
        terminalViews.removeValue(forKey: id)
        updateSessionStatus(id, status: .idle)
    }

    // MARK: - Orchestration

    func dispatchTask(_ task: DispatchTask) {
        taskHistory.append(task)

        // Send the prompt to the target terminal
        if let terminalView = terminalViews[task.targetSessionId] {
            terminalView.send(txt: task.prompt + "\n")
            updateSessionStatus(task.targetSessionId, status: .working)
        }
    }

    func dispatchToAllWorkers(prompt: String) {
        for session in workerSessions {
            let task = DispatchTask(targetSessionId: session.id, prompt: prompt)
            dispatchTask(task)
        }
    }

    func sendInput(_ id: UUID, text: String) {
        if let terminalView = terminalViews[id] {
            terminalView.send(txt: text)
        }
    }
}
