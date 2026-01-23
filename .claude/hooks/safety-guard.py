#!/usr/bin/env python3
"""
Phase 3.6.5: Safety Guard Hook
Prevents catastrophic git and filesystem operations

Blocks:
- rm -rf .git (destroys git history)
- rm -rf outside project directory
- git push --force to main/master
- git reflog expire (removes undo safety net)
- git gc with aggressive pruning
"""

import json
import sys
import re
import os
from pathlib import Path

def is_safe_path(path: str, project_root: str) -> bool:
    """Check if path is within project directory"""
    try:
        # Resolve to absolute path
        abs_path = os.path.abspath(os.path.expanduser(path))
        project_path = os.path.abspath(project_root)

        # Check if path is within project
        return abs_path.startswith(project_path)
    except:
        return False

def validate_command(command: str, project_root: str) -> tuple[bool, str]:
    """
    Validate command for catastrophic operations
    Returns: (is_safe, reason)
    """

    # RULE 1: Block rm -rf .git
    if re.search(r'\brm\s+(-[rf]{2}|-[rf]\s+-[rf])\s+.*\.git\b', command):
        return False, "🚨 BLOCKED: 'rm -rf .git' destroys all git history and is unrecoverable!"

    # RULE 2: Block rm -rf outside project (parent dirs, absolute paths)
    rm_outside_match = re.search(r'\brm\s+(-[rf]{2}|-[rf]\s+-[rf])\s+(.+)', command)
    if rm_outside_match:
        paths = rm_outside_match.group(2).split()
        for path in paths:
            # Remove quotes
            path = path.strip('"\'')

            # Check for parent directory traversal
            if path.startswith('../') or '/../' in path:
                return False, f"🚨 BLOCKED: 'rm -rf {path}' targets parent directory! Only project files can be deleted."

            # Check for absolute paths outside project
            if path.startswith('/') and not is_safe_path(path, project_root):
                return False, f"🚨 BLOCKED: 'rm -rf {path}' targets files outside project directory!"

    # RULE 3: Block git push --force to main/master
    if re.search(r'\bgit\s+push\s+.*(-f|--force)\b', command):
        if re.search(r'\b(main|master)\b', command):
            return False, (
                "🚨 BLOCKED: Force push to main/master is extremely dangerous!\n\n"
                "This PERMANENTLY OVERWRITES shared history and can cause:\n"
                "• Lost work for other developers\n"
                "• Broken CI/CD pipelines\n"
                "• Inability to rollback\n\n"
                "If you REALLY need this:\n"
                "1. Coordinate with your team\n"
                "2. Run outside Claude Code: git push --force-with-lease origin main"
            )

        # Warn but allow force push to other branches
        return True, ""

    # RULE 4: Block git reflog expire (removes undo safety net)
    if re.search(r'\bgit\s+reflog\s+expire\b', command):
        return False, (
            "🚨 BLOCKED: 'git reflog expire' removes your undo safety net!\n\n"
            "This makes it impossible to recover from mistakes like:\n"
            "• Accidental hard resets\n"
            "• Deleted branches\n"
            "• Lost commits\n\n"
            "Reflog is your backup - don't delete it!"
        )

    # RULE 5: Block aggressive git gc (can delete reachable objects)
    if re.search(r'\bgit\s+gc\b.*--aggressive\b', command) and re.search(r'--prune=now\b', command):
        return False, (
            "🚨 BLOCKED: Aggressive 'git gc --prune=now' can destroy recoverable objects!\n\n"
            "This removes objects that might be needed for:\n"
            "• Undoing recent operations\n"
            "• Recovering deleted branches\n"
            "• Accessing reflog history\n\n"
            "Let git handle garbage collection automatically."
        )

    # RULE 6: Warn about git push --force to any branch
    if re.search(r'\bgit\s+push\s+.*(-f|--force)\b', command):
        # Already handled main/master above, this is for other branches
        return True, (
            "⚠️  WARNING: Force push detected. This will overwrite remote branch history.\n"
            "Consider using 'git push --force-with-lease' instead for safety."
        )

    return True, ""

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    # Only process Bash tool calls
    tool_name = input_data.get("tool_name", "")
    if tool_name != "Bash":
        sys.exit(0)

    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")
    project_root = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())

    if not command:
        sys.exit(0)

    # Validate the command
    is_safe, reason = validate_command(command, project_root)

    if not is_safe:
        # Use JSON output with permissionDecision to block with custom message
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason
            }
        }
        print(json.dumps(output))
        sys.exit(0)

    if reason:
        # Warning message (but allow)
        output = {
            "systemMessage": reason
        }
        print(json.dumps(output))

    sys.exit(0)

if __name__ == "__main__":
    main()
