import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            if sessionStore.sessions.isEmpty {
                EmptyStateView()
            } else {
                SessionGridView()
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
        .sheet(isPresented: $sessionStore.showNewSessionSheet) {
            NewSessionSheet()
        }
        .sheet(isPresented: $sessionStore.showDispatchSheet) {
            DispatchSheet()
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        List(selection: $sessionStore.activeSessionId) {
            Section("Conductor") {
                if let conductor = sessionStore.conductorSession {
                    SessionRowView(session: conductor)
                        .tag(conductor.id)
                } else {
                    Text("No conductor")
                        .foregroundColor(.secondary)
                }
            }

            Section("Workers") {
                ForEach(sessionStore.workerSessions) { session in
                    SessionRowView(session: session)
                        .tag(session.id)
                }

                Button(action: { sessionStore.showNewSessionSheet = true }) {
                    Label("Add Worker", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem {
                Button(action: { sessionStore.showDispatchSheet = true }) {
                    Label("Dispatch", systemImage: "paperplane.fill")
                }
                .disabled(sessionStore.workerSessions.isEmpty)
            }
        }
    }
}

struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack {
            Image(systemName: session.role.icon)
                .foregroundColor(session.role.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.headline)
                Text("Port \(session.mcpPort)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: session.status.icon)
                .foregroundColor(session.status.color)
        }
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.house")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Sessions")
                .font(.title)

            Text("Create a session to get started")
                .foregroundColor(.secondary)

            Button("Create Session") {
                sessionStore.showNewSessionSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
}
