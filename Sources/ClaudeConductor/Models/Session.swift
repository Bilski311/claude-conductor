import Foundation
import SwiftUI

/// Represents a single Claude Code session
struct Session: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var directory: String
    var mcpPort: Int
    var role: SessionRole
    var status: SessionStatus

    init(
        id: UUID = UUID(),
        name: String,
        directory: String,
        mcpPort: Int = 55557,
        role: SessionRole = .worker,
        status: SessionStatus = .idle
    ) {
        self.id = id
        self.name = name
        self.directory = directory
        self.mcpPort = mcpPort
        self.role = role
        self.status = status
    }
}

enum SessionRole: String, CaseIterable, Codable {
    case conductor = "Conductor"
    case worker = "Worker"

    var icon: String {
        switch self {
        case .conductor: return "music.note.house.fill"
        case .worker: return "hammer.fill"
        }
    }

    var color: Color {
        switch self {
        case .conductor: return .purple
        case .worker: return .blue
        }
    }
}

enum SessionStatus: String, Codable {
    case idle = "Idle"
    case working = "Working"
    case waitingForInput = "Waiting"
    case error = "Error"
    case disconnected = "Disconnected"

    var icon: String {
        switch self {
        case .idle: return "circle"
        case .working: return "circle.dotted"
        case .waitingForInput: return "questionmark.circle"
        case .error: return "exclamationmark.circle"
        case .disconnected: return "wifi.slash"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .gray
        case .working: return .green
        case .waitingForInput: return .yellow
        case .error: return .red
        case .disconnected: return .orange
        }
    }
}

/// Task to dispatch to a worker
struct DispatchTask: Identifiable {
    let id: UUID
    let targetSessionId: UUID
    let prompt: String
    let timestamp: Date

    init(id: UUID = UUID(), targetSessionId: UUID, prompt: String, timestamp: Date = Date()) {
        self.id = id
        self.targetSessionId = targetSessionId
        self.prompt = prompt
        self.timestamp = timestamp
    }
}
