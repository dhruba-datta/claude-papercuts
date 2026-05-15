#!/usr/bin/env bash
# snapshot.sh — Stop hook for the `unclear` skill.
#
# Runs at the end of every assistant turn. Copies the current
# transcript to a project-local snapshot directory so that the
# `/unclear` skill can recover context after an accidental /clear.
#
# Receives JSON on stdin with at least:
#   { "session_id": "...", "transcript_path": "...", "cwd": "..." }
#
# Writes snapshots to: <cwd>/.papercuts/snapshots/<timestamp>.jsonl
# Keeps the 5 most recent. No network calls. No logs outside the
# snapshot directory.

set -euo pipefail

# Read the hook payload from stdin
payload=$(cat || true)
if [ -z "$payload" ]; then
  exit 0
fi

# Extract fields. Python3 is required by Claude Code itself, so it's
# safe to depend on. One-shot script reading payload from stdin.
parsed=$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("transcript_path", ""))
    print(data.get("cwd", ""))
except Exception:
    pass
' 2>/dev/null || true)

transcript_path=$(printf '%s\n' "$parsed" | sed -n '1p')
cwd=$(printf '%s\n' "$parsed" | sed -n '2p')

# Fail silently if anything is missing — never block the user
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  exit 0
fi
if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
  exit 0
fi

snapshot_dir="$cwd/.papercuts/snapshots"
mkdir -p "$snapshot_dir"

# UTC timestamp for monotonic ordering
ts=$(date -u +%Y%m%dT%H%M%SZ)
dest="$snapshot_dir/$ts.jsonl"

# Copy the transcript (cheap; transcripts are typically <1 MB)
cp "$transcript_path" "$dest"

# Prune: keep the 5 most recent snapshots
retention=5
# shellcheck disable=SC2012
ls -1t "$snapshot_dir"/*.jsonl 2>/dev/null \
  | tail -n +$((retention + 1)) \
  | while IFS= read -r old; do
      rm -f "$old"
    done

exit 0
