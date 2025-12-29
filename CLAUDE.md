# Claude Conductor

A system for orchestrating multiple Claude Code sessions in parallel.

## Default Conductor Workflow

When acting as the conductor, use this pattern:

### 1. Create Workers
```
create_worker(name="worker-name", directory="/path/to/project")
```

### 2. Send Tasks
```
send_to_worker(worker_id="...", message="Your task description")
```

### 3. Wait for Completion & Get Results
```
wait_for_workers(timeout_seconds=120)
```

This automatically polls workers until they're done and returns all outputs.

### 4. Process Results
Synthesize the worker outputs into a final response.

## Example Full Loop

```
# Create specialized workers
api_worker = create_worker(name="api-research", directory="/project")
ui_worker = create_worker(name="ui-research", directory="/project")

# Assign tasks
send_to_worker(api_worker["id"], "Research the API structure...")
send_to_worker(ui_worker["id"], "Research the UI components...")

# Wait and collect results
results = wait_for_workers(timeout_seconds=180)

# Now synthesize the outputs into your final response
```

## MCP Tools Available

### Worker Management
- `create_worker(name, directory, mcp_port)` - Spawn a new worker session
- `send_to_worker(worker_id, message)` - Send task to specific worker
- `broadcast_to_workers(message)` - Send same task to all workers
- `wait_for_workers(timeout_seconds)` - Wait for all workers to finish
- `get_worker_output(worker_id)` - Get output from specific worker
- `get_all_outputs()` - Get outputs from all workers (immediate, no wait)
- `list_workers()` - List all active sessions
- `terminate_worker(worker_id)` - Remove a worker

### Multi-UE Instance Management
- `setup_multi_ue_workspace(main_project_dir, num_instances, base_port)` - One-click setup
- `list_worktrees(project_dir)` - List git worktrees
- `create_worktree(project_dir, worktree_path, branch_name)` - Create worktree
- `remove_worktree(project_dir, worktree_path, force)` - Remove worktree
- `configure_ue_mcp_port(project_dir, port)` - Set UE MCP port in config
- `launch_ue_editor(project_path)` - Launch Unreal Editor
- `check_ue_mcp_connection(port)` - Check if UE MCP is running

## Multi-UE Parallel Development

For working on multiple features simultaneously with separate UE instances:

### Quick Setup (Recommended)
```python
# Set up 2 UE instances with worktrees
setup_multi_ue_workspace("/path/to/Metanoia", num_instances=2, base_port=55557)

# Launch both editors
launch_ue_editor("/path/to/Metanoia")
launch_ue_editor("/path/to/Metanoia-wt2")

# Wait for both to start, then check connections
check_ue_mcp_connection(55557)  # Main
check_ue_mcp_connection(55558)  # Worktree

# Create workers pointing to each instance
create_worker(name="combat", directory="/path/to/Metanoia", mcp_port=55557)
create_worker(name="ui", directory="/path/to/Metanoia-wt2", mcp_port=55558)
```

### How It Works
1. Each worktree is a separate working directory with its own branch
2. Each UE instance reads its MCP port from `Config/DefaultGame.ini`
3. Each worker's `mcp_port` sets `MCP_UE_PORT` env var
4. The Python MCP server reads `MCP_UE_PORT` to connect to the right UE instance

## Notes

- Conductor MCP tools are auto-approved (no permission prompts)
- Workers start fresh sessions (no --resume)
- Conductor uses --resume to maintain conversation continuity
- Each worker can connect to a different UE instance via `mcp_port` parameter
