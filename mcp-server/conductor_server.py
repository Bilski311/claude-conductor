#!/usr/bin/env python3
"""
Claude Conductor MCP Server

Provides tools for a conductor Claude to orchestrate worker Claude sessions.
"""

import asyncio
import json
import os
import pty
import select
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Optional
from mcp.server.fastmcp import FastMCP

# Initialize FastMCP server
mcp = FastMCP("claude-conductor")

@dataclass
class WorkerSession:
    """Represents a worker Claude session"""
    id: str
    name: str
    directory: str
    mcp_port: int
    master_fd: int
    slave_fd: int
    process: subprocess.Popen
    output_buffer: str = ""
    status: str = "running"

# Global state
workers: dict[str, WorkerSession] = {}
next_port = 55558  # Start workers at 55558, conductor is 55557


def read_output(worker: WorkerSession, timeout: float = 0.1) -> str:
    """Read available output from worker's PTY"""
    output = ""
    while True:
        ready, _, _ = select.select([worker.master_fd], [], [], timeout)
        if not ready:
            break
        try:
            data = os.read(worker.master_fd, 4096)
            if data:
                output += data.decode('utf-8', errors='replace')
            else:
                break
        except OSError:
            break
    worker.output_buffer += output
    return output


def strip_ansi(text: str) -> str:
    """Remove ANSI escape codes for cleaner output"""
    import re
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    return ansi_escape.sub('', text)


@mcp.tool()
def create_worker(name: str, directory: str, initial_prompt: Optional[str] = None) -> dict:
    """
    Create a new worker Claude session.

    Args:
        name: Name for the worker (e.g., "combat-worker", "ui-worker")
        directory: Working directory for the worker
        initial_prompt: Optional initial prompt to send to the worker

    Returns:
        Dict with worker ID and status
    """
    global next_port

    worker_id = f"worker-{len(workers) + 1}"
    port = next_port
    next_port += 1

    # Create PTY
    master_fd, slave_fd = pty.openpty()

    # Set up environment
    env = os.environ.copy()
    env["TERM"] = "xterm-256color"
    env["MCP_UE_PORT"] = str(port)

    # Start Claude process
    process = subprocess.Popen(
        ["/bin/zsh", "-l", "-i", "-c", "claude"],
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        cwd=directory,
        env=env,
        preexec_fn=os.setsid
    )

    worker = WorkerSession(
        id=worker_id,
        name=name,
        directory=directory,
        mcp_port=port,
        master_fd=master_fd,
        slave_fd=slave_fd,
        process=process
    )

    workers[worker_id] = worker

    # Wait for Claude to start up
    asyncio.get_event_loop().run_in_executor(None, lambda: read_output(worker, timeout=3.0))

    # Send initial prompt if provided
    if initial_prompt:
        os.write(master_fd, (initial_prompt + "\n").encode())

    return {
        "worker_id": worker_id,
        "name": name,
        "directory": directory,
        "mcp_port": port,
        "status": "created"
    }


@mcp.tool()
def send_to_worker(worker_id: str, message: str) -> dict:
    """
    Send a message/prompt to a specific worker.

    Args:
        worker_id: The ID of the worker to send to
        message: The message or prompt to send

    Returns:
        Dict with status
    """
    if worker_id not in workers:
        return {"error": f"Worker {worker_id} not found"}

    worker = workers[worker_id]

    if worker.process.poll() is not None:
        worker.status = "terminated"
        return {"error": f"Worker {worker_id} has terminated"}

    # Send message
    os.write(worker.master_fd, (message + "\n").encode())

    return {
        "worker_id": worker_id,
        "status": "message_sent",
        "message": message
    }


@mcp.tool()
def broadcast_to_workers(message: str) -> dict:
    """
    Send a message to ALL workers.

    Args:
        message: The message or prompt to send to all workers

    Returns:
        Dict with results for each worker
    """
    results = {}
    for worker_id in workers:
        result = send_to_worker(worker_id, message)
        results[worker_id] = result

    return {
        "broadcast_message": message,
        "results": results,
        "workers_count": len(results)
    }


@mcp.tool()
def get_worker_output(worker_id: str, lines: int = 50) -> dict:
    """
    Get recent output from a worker.

    Args:
        worker_id: The ID of the worker
        lines: Number of recent lines to return (default 50)

    Returns:
        Dict with worker output
    """
    if worker_id not in workers:
        return {"error": f"Worker {worker_id} not found"}

    worker = workers[worker_id]

    # Read any new output
    read_output(worker, timeout=0.5)

    # Get last N lines, strip ANSI codes
    output_lines = strip_ansi(worker.output_buffer).split('\n')
    recent_output = '\n'.join(output_lines[-lines:])

    # Check if process is still running
    if worker.process.poll() is not None:
        worker.status = "terminated"

    return {
        "worker_id": worker_id,
        "name": worker.name,
        "status": worker.status,
        "output": recent_output
    }


@mcp.tool()
def list_workers() -> dict:
    """
    List all worker sessions and their status.

    Returns:
        Dict with all workers and their info
    """
    worker_list = []
    for worker_id, worker in workers.items():
        # Check if still running
        if worker.process.poll() is not None:
            worker.status = "terminated"

        worker_list.append({
            "id": worker_id,
            "name": worker.name,
            "directory": worker.directory,
            "mcp_port": worker.mcp_port,
            "status": worker.status
        })

    return {
        "workers": worker_list,
        "count": len(worker_list)
    }


@mcp.tool()
def terminate_worker(worker_id: str) -> dict:
    """
    Terminate a worker session.

    Args:
        worker_id: The ID of the worker to terminate

    Returns:
        Dict with termination status
    """
    if worker_id not in workers:
        return {"error": f"Worker {worker_id} not found"}

    worker = workers[worker_id]

    # Send exit command first
    try:
        os.write(worker.master_fd, b"/exit\n")
    except:
        pass

    # Give it a moment to exit gracefully
    try:
        worker.process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        worker.process.terminate()
        try:
            worker.process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            worker.process.kill()

    # Clean up file descriptors
    try:
        os.close(worker.master_fd)
        os.close(worker.slave_fd)
    except:
        pass

    worker.status = "terminated"
    del workers[worker_id]

    return {
        "worker_id": worker_id,
        "status": "terminated"
    }


@mcp.tool()
def get_all_outputs() -> dict:
    """
    Get recent output from ALL workers at once.
    Useful for checking on everyone's progress.

    Returns:
        Dict with output from all workers
    """
    all_outputs = {}
    for worker_id in workers:
        result = get_worker_output(worker_id, lines=20)
        all_outputs[worker_id] = result

    return {
        "outputs": all_outputs,
        "count": len(all_outputs)
    }


if __name__ == "__main__":
    mcp.run()
