#!/usr/bin/env python3
"""
Claude Conductor MCP Server

Provides tools for a conductor Claude to orchestrate worker Claude sessions.
Communicates with the Claude Conductor app via HTTP API on port 7422.
"""

import json
import urllib.request
import urllib.error
from typing import Optional
from mcp.server.fastmcp import FastMCP

# Initialize FastMCP server
mcp = FastMCP("claude-conductor")

# HTTP API base URL (Claude Conductor app)
API_BASE = "http://127.0.0.1:7422"


def api_request(method: str, path: str, body: dict = None) -> dict:
    """Make an HTTP request to the Claude Conductor app API"""
    url = f"{API_BASE}{path}"

    data = None
    if body:
        data = json.dumps(body).encode('utf-8')

    request = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={'Content-Type': 'application/json'} if data else {}
    )

    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.URLError as e:
        return {"error": f"Failed to connect to Claude Conductor app: {e}"}
    except json.JSONDecodeError:
        return {"error": "Invalid response from Claude Conductor app"}


def strip_ansi(text: str) -> str:
    """Remove ANSI escape codes for cleaner output"""
    import re
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    return ansi_escape.sub('', text)


@mcp.tool()
def create_worker(name: str, directory: str, mcp_port: int = 55558) -> dict:
    """
    Create a new worker Claude session that appears in the Conductor UI.

    Args:
        name: Name for the worker (e.g., "combat-worker", "ui-worker")
        directory: Working directory for the worker
        mcp_port: MCP port for the worker (default 55558)

    Returns:
        Dict with worker ID and status
    """
    result = api_request("POST", "/sessions", {
        "name": name,
        "directory": directory,
        "mcp_port": mcp_port,
        "role": "Worker"
    })

    return result


@mcp.tool()
def send_to_worker(worker_id: str, message: str) -> dict:
    """
    Send a message/prompt to a specific worker.

    Args:
        worker_id: The UUID of the worker to send to
        message: The message or prompt to send

    Returns:
        Dict with status
    """
    result = api_request("POST", f"/sessions/{worker_id}/send", {
        "message": message
    })

    return result


@mcp.tool()
def broadcast_to_workers(message: str) -> dict:
    """
    Send a message to ALL workers.

    Args:
        message: The message or prompt to send to all workers

    Returns:
        Dict with results for each worker
    """
    # First get all sessions
    sessions_result = api_request("GET", "/sessions")

    if "error" in sessions_result:
        return sessions_result

    results = {}
    workers = [s for s in sessions_result.get("sessions", []) if s.get("role") == "Worker"]

    for worker in workers:
        worker_id = worker["id"]
        result = send_to_worker(worker_id, message)
        results[worker_id] = result

    return {
        "broadcast_message": message,
        "results": results,
        "workers_count": len(results)
    }


@mcp.tool()
def get_worker_output(worker_id: str) -> dict:
    """
    Get recent output from a worker.

    Args:
        worker_id: The UUID of the worker

    Returns:
        Dict with worker output
    """
    result = api_request("GET", f"/sessions/{worker_id}/output")

    if "output" in result:
        result["output"] = strip_ansi(result["output"])

    return result


@mcp.tool()
def list_workers() -> dict:
    """
    List all sessions (conductor and workers) and their status.

    Returns:
        Dict with all sessions and their info
    """
    result = api_request("GET", "/sessions")
    return result


@mcp.tool()
def terminate_worker(worker_id: str) -> dict:
    """
    Terminate/remove a worker session.

    Args:
        worker_id: The UUID of the worker to terminate

    Returns:
        Dict with termination status
    """
    result = api_request("DELETE", f"/sessions/{worker_id}")
    return result


@mcp.tool()
def get_all_outputs() -> dict:
    """
    Get recent output from ALL workers at once.
    Useful for checking on everyone's progress.

    Returns:
        Dict with output from all workers
    """
    # First get all sessions
    sessions_result = api_request("GET", "/sessions")

    if "error" in sessions_result:
        return sessions_result

    all_outputs = {}
    workers = [s for s in sessions_result.get("sessions", []) if s.get("role") == "Worker"]

    for worker in workers:
        worker_id = worker["id"]
        output_result = get_worker_output(worker_id)
        all_outputs[worker["name"]] = {
            "id": worker_id,
            "status": worker.get("status", "Unknown"),
            "output": output_result.get("output", "")[:2000]  # Limit output size
        }

    return {
        "outputs": all_outputs,
        "count": len(all_outputs)
    }


if __name__ == "__main__":
    mcp.run()
