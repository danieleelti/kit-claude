#!/usr/bin/env python3
"""
skill-finder installer — adds the SessionStart hook to Claude Code settings.

Usage:
    python3 install.py

Idempotent: safe to run multiple times.
"""

import json
import sys
from pathlib import Path

SETTINGS_PATH = Path.home() / ".claude" / "settings.json"
HOOK_COMMAND = f'python3 "{Path.home() / ".claude" / "skills" / "skill-finder" / "scripts" / "session_hook.py"}"'


def main():
    # Read or create settings
    settings = {}
    if SETTINGS_PATH.is_file():
        try:
            raw = SETTINGS_PATH.read_text(encoding="utf-8")
            settings = json.loads(raw)
        except (json.JSONDecodeError, OSError) as e:
            print(f"[skill-finder] Warning: could not parse {SETTINGS_PATH}: {e}")
            print("[skill-finder] Creating backup and starting fresh...")
            backup = SETTINGS_PATH.with_suffix(".json.bak")
            try:
                SETTINGS_PATH.rename(backup)
                print(f"[skill-finder] Backup saved to {backup}")
            except OSError:
                pass
            settings = {}

    # Ensure hooks structure exists
    if "hooks" not in settings:
        settings["hooks"] = {}
    if "SessionStart" not in settings["hooks"]:
        settings["hooks"]["SessionStart"] = []

    session_hooks = settings["hooks"]["SessionStart"]

    # Check if already installed
    for entry in session_hooks:
        hooks_list = entry.get("hooks", [])
        for h in hooks_list:
            if h.get("type") == "command" and "skill-finder" in h.get("command", ""):
                print("[skill-finder] Hook already installed. Nothing to do.")
                return

    # Add the hook
    new_entry = {
        "hooks": [
            {
                "type": "command",
                "command": HOOK_COMMAND,
                "timeout": 30,
            }
        ]
    }
    session_hooks.append(new_entry)

    # Write settings
    try:
        SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
        SETTINGS_PATH.write_text(
            json.dumps(settings, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        print("[skill-finder] SessionStart hook installed successfully.")
        print(f"[skill-finder] Settings written to: {SETTINGS_PATH}")
    except OSError as e:
        print(f"[skill-finder] Error writing settings: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
