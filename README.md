# Claude Conductor

A Mac desktop app for orchestrating multiple Claude Code sessions in parallel.

## Vision

Run multiple Claude Code instances across different project worktrees, with a main "conductor" session that can dispatch tasks to worker sessions - while you maintain full visibility and control over all conversations.

```
┌─────────────────────────────────────────────────────────────────┐
│ Claude Conductor                                          ─ □ x │
├─────────────────────────────────────────────────────────────────┤
│ [Main: Metanoia] [Combat: Metanoia-combat] [UI: Metanoia-ui]    │
├───────────────────────────┬─────────────────────────────────────┤
│                           │                                     │
│  Main Conductor           │  Combat Worker                      │
│  /private/Metanoia        │  /private/Metanoia-combat           │
│  Port: 55557              │  Port: 55558                        │
│                           │                                     │
│  > Dispatch: "Implement   │  Claude: I'll implement the         │
│    enemy AI to combat     │  enemy AI patrol system...          │
│    worker"                │                                     │
│                           │  [typing indicator]                 │
│  Conductor: Task sent.    │                                     │
│  Monitoring combat...     │                                     │
│                           │                                     │
├───────────────────────────┼─────────────────────────────────────┤
│  UI Worker                │  [Add Worker +]                     │
│  /private/Metanoia-ui     │                                     │
│  Port: 55559              │  Quick Actions:                     │
│                           │  • Dispatch to all workers          │
│  Idle - waiting for task  │  • Sync all branches                │
│                           │  • Status report                    │
│                           │                                     │
└───────────────────────────┴─────────────────────────────────────┘
```

## Features

### MVP (v0.1)
- [ ] Split-pane terminal interface
- [ ] Spawn Claude Code sessions in configurable directories
- [ ] Each session connects to its own MCP server/port
- [ ] Click any pane to focus and type
- [ ] Visual status indicators (idle, working, waiting for input)

### Orchestration (v0.2)
- [ ] "Main" conductor session designation
- [ ] Dispatch tasks from main to workers via command or UI
- [ ] Worker status monitoring
- [ ] Task queue visualization

### Project Management (v0.3)
- [ ] Git worktree integration
- [ ] Auto-configure MCP ports per worktree
- [ ] Branch status visualization
- [ ] Merge conflict detection

### Advanced (v1.0)
- [ ] Task templates (e.g., "implement feature", "fix bug", "review code")
- [ ] Session recording/playback
- [ ] Cost tracking across sessions
- [ ] Collaborative mode (multiple humans + AIs)

## Tech Stack

- **SwiftUI** - Native Mac UI
- **Swift** - Core logic
- **PTY** - Terminal emulation
- **Claude Code CLI** - Underlying AI interface

## Architecture

```
┌─────────────────────────────────────────────┐
│              Claude Conductor               │
├─────────────────────────────────────────────┤
│  UI Layer (SwiftUI)                         │
│  ├── SessionTabView                         │
│  ├── TerminalPaneView                       │
│  ├── StatusBarView                          │
│  └── DispatchPanelView                      │
├─────────────────────────────────────────────┤
│  Session Manager                            │
│  ├── SessionStore (ObservableObject)        │
│  ├── Session (id, directory, port, status)  │
│  └── Orchestrator (dispatch, monitor)       │
├─────────────────────────────────────────────┤
│  Terminal Layer                             │
│  ├── PTYSession (pseudo-terminal)           │
│  ├── ANSIParser (terminal escape codes)     │
│  └── InputHandler (keyboard/mouse)          │
├─────────────────────────────────────────────┤
│  Integration Layer                          │
│  ├── ClaudeCodeLauncher                     │
│  ├── MCPConfigManager                       │
│  └── GitWorktreeManager                     │
└─────────────────────────────────────────────┘
```

## Getting Started

```bash
# Clone
git clone https://github.com/Bilski311/claude-conductor.git
cd claude-conductor

# Build
swift build

# Run
swift run ClaudeConductor
```

## Development

```bash
# Open in Xcode
open Package.swift

# Or build from command line
swift build
swift test
```

## Related Projects

- [Claude Code](https://claude.ai/claude-code) - The CLI this app orchestrates
- [UnrealMCP](https://github.com/Bilski311/unreal-mcp) - MCP plugin for Unreal Engine

## License

MIT
