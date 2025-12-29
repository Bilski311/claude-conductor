import Foundation
import SwiftUI
import Combine
import SwiftTerm
import Network

/// Main state management for all Claude sessions
@MainActor
class SessionStore: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var activeSessionId: UUID?
    @Published var showNewSessionSheet = false
    @Published var showDispatchSheet = false
    @Published var taskHistory: [DispatchTask] = []

    private var terminalViews: [UUID: LocalProcessTerminalView] = [:]
    private var outputBuffers: [UUID: String] = [:]
    private var httpServer: HTTPAPIServer?

    private static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude-conductor")
    private static let sessionsFile = configDirectory.appendingPathComponent("sessions.json")

    init() {
        loadSessions()

        // If no sessions exist, create a default conductor
        if sessions.isEmpty {
            let conductorSession = Session(
                name: "Conductor",
                directory: "/Users/dominikbilski/private/claude-conductor",
                mcpPort: 55557,
                role: .conductor
            )
            sessions.append(conductorSession)
            activeSessionId = conductorSession.id
            saveSessions()
        } else {
            activeSessionId = sessions.first?.id
        }

        // Start HTTP API server for MCP communication
        startHTTPServer()
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

    // MARK: - Persistence

    private func loadSessions() {
        // Create config directory if needed
        try? FileManager.default.createDirectory(
            at: Self.configDirectory,
            withIntermediateDirectories: true
        )

        guard FileManager.default.fileExists(atPath: Self.sessionsFile.path) else { return }

        do {
            let data = try Data(contentsOf: Self.sessionsFile)
            let decoded = try JSONDecoder().decode([Session].self, from: data)
            // Reset status to idle on load (terminals will restart)
            sessions = decoded.map { session in
                var s = session
                s.status = .idle
                return s
            }
            print("Loaded \(sessions.count) sessions from disk")
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }

    func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: Self.sessionsFile)
            print("Saved \(sessions.count) sessions to disk")
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }

    // MARK: - Session Management

    func addSession(_ session: Session) {
        sessions.append(session)
        if activeSessionId == nil {
            activeSessionId = session.id
        }
        saveSessions()
    }

    func removeSession(_ id: UUID) {
        terminalViews.removeValue(forKey: id)
        outputBuffers.removeValue(forKey: id)
        sessions.removeAll { $0.id == id }
        if activeSessionId == id {
            activeSessionId = sessions.first?.id
        }
        saveSessions()
    }

    func updateSessionStatus(_ id: UUID, status: SessionStatus) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].status = status
        }
    }

    // MARK: - Terminal View Management

    func setTerminalView(_ id: UUID, view: LocalProcessTerminalView) {
        terminalViews[id] = view
        outputBuffers[id] = ""
        updateSessionStatus(id, status: .working)
    }

    func getTerminalView(_ id: UUID) -> LocalProcessTerminalView? {
        terminalViews[id]
    }

    func appendOutput(_ id: UUID, text: String) {
        if outputBuffers[id] != nil {
            outputBuffers[id]! += text
            // Keep buffer reasonable size
            if outputBuffers[id]!.count > 100000 {
                outputBuffers[id] = String(outputBuffers[id]!.suffix(50000))
            }
        }
    }

    func getOutput(_ id: UUID, lines: Int = 50) -> String {
        guard let buffer = outputBuffers[id] else { return "" }
        let allLines = buffer.components(separatedBy: "\n")
        return allLines.suffix(lines).joined(separator: "\n")
    }

    func restartSession(_ id: UUID) {
        terminalViews.removeValue(forKey: id)
        outputBuffers.removeValue(forKey: id)
        updateSessionStatus(id, status: .idle)
    }

    // MARK: - Orchestration

    func dispatchTask(_ task: DispatchTask) {
        taskHistory.append(task)

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

    // MARK: - HTTP API Server

    private func startHTTPServer() {
        httpServer = HTTPAPIServer(port: 7422, sessionStore: self)
        httpServer?.start()
    }
}

// MARK: - HTTP API Server for MCP Communication

class HTTPAPIServer {
    private var listener: NWListener?
    private let port: UInt16
    private weak var sessionStore: SessionStore?

    init(port: UInt16, sessionStore: SessionStore) {
        self.port = port
        self.sessionStore = sessionStore
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            // Force IPv4 for compatibility
            if let ipOptions = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
                ipOptions.version = .v4
            }
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("HTTP API server listening on port \(self.port)")
                case .failed(let error):
                    print("HTTP API server failed: \(error)")
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: DispatchQueue.global(qos: .userInitiated))
        } catch {
            print("Failed to start HTTP server: \(error)")
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            if let data = data, let request = String(data: data, encoding: .utf8) {
                let response = self?.handleRequest(request) ?? "HTTP/1.1 500 Error\r\n\r\n"
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            } else if let error = error {
                print("Connection error: \(error)")
                connection.cancel()
            }
        }
    }

    private func handleRequest(_ request: String) -> String {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            return httpResponse(400, body: ["error": "Bad request"])
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            return httpResponse(400, body: ["error": "Bad request"])
        }

        let method = parts[0]
        let path = parts[1]

        // Find body (after empty line)
        var body: [String: Any]?
        if let emptyLineIndex = lines.firstIndex(of: "") {
            let bodyString = lines.dropFirst(emptyLineIndex + 1).joined(separator: "\r\n")
            if let data = bodyString.data(using: .utf8) {
                body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
        }

        // Route requests
        switch (method, path) {
        case ("GET", "/sessions"):
            return listSessions()
        case ("POST", "/sessions"):
            return createSession(body: body)
        case ("POST", _) where path.hasPrefix("/sessions/") && path.hasSuffix("/send"):
            let id = extractSessionId(from: path)
            return sendToSession(id: id, body: body)
        case ("GET", _) where path.hasPrefix("/sessions/") && path.hasSuffix("/output"):
            let id = extractSessionId(from: path)
            return getSessionOutput(id: id)
        case ("DELETE", _) where path.hasPrefix("/sessions/"):
            let id = extractSessionId(from: path)
            return deleteSession(id: id)
        default:
            return httpResponse(404, body: ["error": "Not found"])
        }
    }

    private func extractSessionId(from path: String) -> String {
        // /sessions/{id}/send or /sessions/{id}/output or /sessions/{id}
        let components = path.components(separatedBy: "/")
        if components.count >= 3 {
            return components[2]
        }
        return ""
    }

    private func listSessions() -> String {
        guard let store = sessionStore else {
            return httpResponse(500, body: ["error": "Store unavailable"])
        }

        var sessionList: [[String: Any]] = []

        // Access MainActor-isolated data synchronously from main queue
        DispatchQueue.main.sync {
            sessionList = store.sessions.map { session in
                [
                    "id": session.id.uuidString,
                    "name": session.name,
                    "directory": session.directory,
                    "mcp_port": session.mcpPort,
                    "role": session.role.rawValue,
                    "status": session.status.rawValue
                ] as [String: Any]
            }
        }

        return httpResponse(200, body: ["sessions": sessionList, "count": sessionList.count])
    }

    private func createSession(body: [String: Any]?) -> String {
        guard let store = sessionStore,
              let body = body,
              let name = body["name"] as? String,
              let directory = body["directory"] as? String else {
            return httpResponse(400, body: ["error": "Missing name or directory"])
        }

        let mcpPort = body["mcp_port"] as? Int ?? 55558
        let roleString = body["role"] as? String ?? "Worker"
        let role: SessionRole = roleString.lowercased() == "conductor" ? .conductor : .worker

        let session = Session(
            name: name,
            directory: directory,
            mcpPort: mcpPort,
            role: role
        )

        DispatchQueue.main.async {
            store.addSession(session)
        }

        return httpResponse(201, body: [
            "id": session.id.uuidString,
            "name": session.name,
            "directory": session.directory,
            "mcp_port": session.mcpPort,
            "status": "created"
        ])
    }

    private func sendToSession(id: String, body: [String: Any]?) -> String {
        guard let store = sessionStore,
              let uuid = UUID(uuidString: id),
              let body = body,
              let message = body["message"] as? String else {
            return httpResponse(400, body: ["error": "Invalid request"])
        }

        DispatchQueue.main.async {
            store.sendInput(uuid, text: message + "\n")
        }

        return httpResponse(200, body: ["status": "sent", "id": id])
    }

    private func getSessionOutput(id: String) -> String {
        guard let store = sessionStore,
              let uuid = UUID(uuidString: id) else {
            return httpResponse(400, body: ["error": "Invalid session ID"])
        }

        var output = ""
        var sessionName = "Unknown"
        var sessionStatus = "Unknown"

        DispatchQueue.main.sync {
            output = store.getOutput(uuid, lines: 100)
            if let session = store.sessions.first(where: { $0.id == uuid }) {
                sessionName = session.name
                sessionStatus = session.status.rawValue
            }
        }

        return httpResponse(200, body: [
            "id": id,
            "name": sessionName,
            "status": sessionStatus,
            "output": output
        ])
    }

    private func deleteSession(id: String) -> String {
        guard let store = sessionStore,
              let uuid = UUID(uuidString: id) else {
            return httpResponse(400, body: ["error": "Invalid session ID"])
        }

        DispatchQueue.main.async {
            store.removeSession(uuid)
        }

        return httpResponse(200, body: ["status": "deleted", "id": id])
    }

    private func httpResponse(_ code: Int, body: [String: Any]) -> String {
        let statusText: String
        switch code {
        case 200: statusText = "OK"
        case 201: statusText = "Created"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        let jsonData = try? JSONSerialization.data(withJSONObject: body)
        let jsonString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        return """
        HTTP/1.1 \(code) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(jsonString.utf8.count)\r
        Connection: close\r
        \r
        \(jsonString)
        """
    }
}
