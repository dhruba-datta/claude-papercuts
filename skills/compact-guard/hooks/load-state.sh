#!/usr/bin/env bash
# load-state.sh — SessionStart hook for the `compact-guard` skill.
#
# Fires at the start of every session, but ONLY emits output when
# source == "compact". The post-compact session reads the most recent
# snapshot from .papercuts/compact-snapshots/ and emits it on stdout
# — Claude Code auto-injects SessionStart stdout as additional context
# at the top of the post-compact turn.
#
# Receives JSON on stdin (Claude Code's SessionStart hook contract):
#   { "session_id", "transcript_path", "cwd",
#     "hook_event_name", "source", "model" }
#
# Fails open: never blocks the user on internal errors.

set -u

payload=$(cat || true)
if [ -z "$payload" ]; then
  exit 0
fi

python3 - "$payload" <<'PY' || exit 0
import json, os, sys


def load_payload():
    try:
        return json.loads(sys.argv[1])
    except Exception:
        return None


def main():
    p = load_payload()
    if not p:
        return
    # Only fire post-compact — other SessionStart sources are not our concern
    if p.get("source") != "compact":
        return

    cwd = p.get("cwd", "")
    if not cwd or not os.path.isdir(cwd):
        return

    snap_dir = os.path.join(cwd, ".papercuts", "compact-snapshots")
    if not os.path.isdir(snap_dir):
        return

    snaps = sorted(
        (p for p in os.listdir(snap_dir) if p.endswith(".md")),
        reverse=True,
    )
    if not snaps:
        return

    latest = os.path.join(snap_dir, snaps[0])
    try:
        with open(latest, encoding="utf-8") as f:
            content = f.read()
    except Exception:
        return

    print("Post-compact state restored by claude-papercuts:compact-guard.")
    print(f"Snapshot: {os.path.relpath(latest, cwd)}")
    print()
    print(content)


try:
    main()
except Exception:
    pass
PY
exit 0
