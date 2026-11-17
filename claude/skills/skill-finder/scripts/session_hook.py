#!/usr/bin/env python3
"""
skill-finder session hook — runs at SessionStart.

Executes scan.py for the current project and outputs suggestions
for Claude to interpret. Fails silently on any error.
"""

import os
import subprocess
import sys
from pathlib import Path

def main():
    try:
        # Read and discard stdin (Claude sends JSON event data)
        try:
            sys.stdin.read()
        except Exception:
            pass

        # Determine project directory
        project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
        if not project_dir:
            project_dir = os.getcwd()

        project_path = Path(project_dir)
        if not project_path.is_dir():
            sys.exit(0)

        # Run scan.py
        scan_script = Path(__file__).parent / "scan.py"
        if not scan_script.is_file():
            sys.exit(0)

        result = subprocess.run(
            [sys.executable, str(scan_script), str(project_path)],
            capture_output=True,
            text=True,
            timeout=30,
        )

        output = result.stdout.strip()

        # Only print if there are actual suggestions (not "already configured" or "no skills")
        if output and "[skill-finder] Suggerimenti" in output:
            print(output)

    except Exception:
        # Never block session start
        pass

    sys.exit(0)


if __name__ == "__main__":
    main()
