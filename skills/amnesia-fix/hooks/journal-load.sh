#!/usr/bin/env bash
# journal-load.sh — SessionStart hook for the `amnesia-fix` skill.
#
# Runs at the start of every Claude Code session (startup, resume,
# clear, or compact). Reads the project-local journal and prints the
# last N entries to stdout — Claude Code auto-injects SessionStart
# stdout as additional context. No more amnesiac sessions.
#
# Receives JSON on stdin (Claude Code's SessionStart hook contract):
#   { "session_id", "transcript_path", "cwd",
#     "hook_event_name", "source", "model" }
#
# Fails open: never blocks the user on internal errors.

set -u

DEFAULT_ENTRIES=3

payload=$(cat || true)
if [ -z "$payload" ]; then
  exit 0
fi

python3 - "$payload" <<PY || exit 0
import json, os, sys

DEFAULT_ENTRIES = $DEFAULT_ENTRIES

def load_payload():
    try:
        return json.loads(sys.argv[1])
    except Exception:
        return None


def last_entries(text, n):
    """Return the last n '## ' entries from the journal as strings."""
    if not text:
        return []
    blocks = []
    current = []
    for line in text.splitlines():
        if line.startswith("## "):
            if current and any(l.strip() for l in current):
                blocks.append("\n".join(current).strip())
            current = [line]
        else:
            current.append(line)
    if current and any(l.strip() for l in current):
        blocks.append("\n".join(current).strip())
    return blocks[-n:]


def main():
    p = load_payload()
    if not p:
        return
    cwd = p.get("cwd", "")
    if not cwd or not os.path.isdir(cwd):
        return

    journal_path = os.path.join(cwd, ".papercuts", "journal.md")
    if not os.path.isfile(journal_path):
        return

    try:
        with open(journal_path, encoding="utf-8") as f:
            text = f.read()
    except Exception:
        return

    entries = last_entries(text, DEFAULT_ENTRIES)
    if not entries:
        return

    source = p.get("source", "startup")
    print(f"Prior session journal (claude-papercuts:amnesia-fix). "
          f"Loaded on {source}. Newest first.")
    print()
    for block in reversed(entries):
        print(block)
        print()


try:
    main()
except Exception:
    pass
PY
exit 0
