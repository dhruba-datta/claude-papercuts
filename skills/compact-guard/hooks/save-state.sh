#!/usr/bin/env bash
# save-state.sh — PreCompact hook for the `compact-guard` skill.
#
# Fires immediately before /compact (manual) or auto-compact runs.
# Reads the transcript and writes a structured snapshot of in-progress
# work to .papercuts/compact-snapshots/<timestamp>.md so the post-compact
# session can resume without re-discovering everything.
#
# Captures:
#   - The most recent user message (the "current task")
#   - Active TodoWrite todos (pending + in_progress only)
#   - File paths edited this session (Edit / Write / MultiEdit)
#   - The last assistant text block (likely the working plan / summary)
#   - The compact trigger (auto vs manual)
#
# Receives JSON on stdin (Claude Code's PreCompact hook contract):
#   { "session_id", "transcript_path", "cwd", "hook_event_name", "trigger" }
#
# Fails open: never blocks the compact on internal errors. Keeps at
# most 5 snapshots in .papercuts/compact-snapshots/ — older ones are
# pruned so the dir doesn't grow without bound.

set -u

MAX_SNAPSHOTS=5

payload=$(cat || true)
if [ -z "$payload" ]; then
  exit 0
fi

python3 - "$payload" "$MAX_SNAPSHOTS" <<'PY' || exit 0
import json, os, sys, re
from datetime import datetime, timezone

MAX_TODO_ITEMS = 12
MAX_FILES = 10
MAX_PLAN_CHARS = 1500
MAX_TASK_CHARS = 400


def load_payload():
    try:
        return json.loads(sys.argv[1])
    except Exception:
        return None


def max_snapshots():
    try:
        return int(sys.argv[2])
    except Exception:
        return 5


def read_transcript(path):
    try:
        with open(path, encoding="utf-8") as f:
            return [json.loads(line) for line in f if line.strip()]
    except Exception:
        return []


def extract_text(msg):
    if not isinstance(msg, dict):
        return ""
    content = msg.get("content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(block.get("text", ""))
        return "\n".join(parts)
    return ""


def find_last_assistant_text(entries):
    for entry in reversed(entries):
        msg = entry.get("message", {})
        role = msg.get("role") if isinstance(msg, dict) else None
        if entry.get("type") == "assistant" or role == "assistant":
            t = extract_text(msg)
            if t.strip():
                return t
    return ""


def find_last_user_text(entries):
    """The current task — the *most recent* user message, not the first."""
    for entry in reversed(entries):
        msg = entry.get("message", {})
        role = msg.get("role") if isinstance(msg, dict) else None
        if entry.get("type") == "user" or role == "user":
            content = msg.get("content", "") if isinstance(msg, dict) else ""
            if isinstance(content, str) and content.strip():
                # Skip tool_result-only messages
                return content.strip()
            if isinstance(content, list):
                # Skip messages that are purely tool_result blocks
                texts = [c.get("text", "").strip() for c in content
                         if isinstance(c, dict) and c.get("type") == "text"]
                texts = [t for t in texts if t]
                if texts:
                    return "\n".join(texts).strip()
    return ""


def find_latest_todos(entries):
    """Return the most-recent TodoWrite tool_use's todos list (pending +
    in_progress only). Completed todos aren't useful — we want to know
    what's still on the table at compact-time."""
    for entry in reversed(entries):
        msg = entry.get("message", {})
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            if block.get("name") != "TodoWrite":
                continue
            todos = block.get("input", {}).get("todos", [])
            if not isinstance(todos, list):
                continue
            active = []
            for t in todos:
                if not isinstance(t, dict):
                    continue
                status = t.get("status", "")
                if status in ("pending", "in_progress"):
                    active.append({
                        "status": status,
                        "content": str(t.get("content", "")).strip(),
                    })
            return active
    return []


def find_files_touched(entries):
    files = []
    seen = set()
    for entry in entries:
        msg = entry.get("message", {})
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            if block.get("name") in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
                path = block.get("input", {}).get("file_path", "")
                if path and path not in seen:
                    seen.add(path)
                    files.append(path)
    return files


def trim(s, n):
    s = s.strip()
    if len(s) <= n:
        return s
    return s[: n - 1] + "…"


def write_snapshot(cwd, payload, entries):
    snap_dir = os.path.join(cwd, ".papercuts", "compact-snapshots")
    os.makedirs(snap_dir, exist_ok=True)

    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    snap_path = os.path.join(snap_dir, f"{ts}.md")

    trigger = payload.get("trigger", "unknown")
    session = payload.get("session_id", "unknown")[:12]

    task = trim(find_last_user_text(entries), MAX_TASK_CHARS)
    todos = find_latest_todos(entries)[:MAX_TODO_ITEMS]
    files = find_files_touched(entries)[:MAX_FILES]
    plan = trim(find_last_assistant_text(entries), MAX_PLAN_CHARS)

    # If literally nothing useful was captured, skip
    if not (task or todos or files or plan):
        return

    lines = [
        f"# compact-guard snapshot",
        f"",
        f"- **When:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
        f"- **Trigger:** {trigger}-compact",
        f"- **Session:** {session}",
        f"",
    ]
    if task:
        lines.append("## Current task (last user message)")
        lines.append(f"> {task}".replace("\n", "\n> "))
        lines.append("")
    if todos:
        lines.append("## Active todos")
        for t in todos:
            mark = "[in_progress]" if t["status"] == "in_progress" else "[pending]"
            lines.append(f"- {mark} {t['content']}")
        lines.append("")
    if files:
        lines.append("## Files edited this session")
        for f in files:
            lines.append(f"- `{f}`")
        lines.append("")
    if plan:
        lines.append("## Last assistant message (plan / summary)")
        lines.append("")
        lines.append(plan)
        lines.append("")

    try:
        with open(snap_path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
    except Exception:
        return

    # Prune oldest, keep N
    try:
        snaps = sorted(
            (p for p in os.listdir(snap_dir) if p.endswith(".md")),
            reverse=True,
        )
        for old in snaps[max_snapshots():]:
            try:
                os.remove(os.path.join(snap_dir, old))
            except Exception:
                pass
    except Exception:
        pass


def main():
    p = load_payload()
    if not p:
        return
    transcript_path = p.get("transcript_path")
    cwd = p.get("cwd")
    if not transcript_path or not os.path.isfile(transcript_path):
        return
    if not cwd or not os.path.isdir(cwd):
        return

    entries = read_transcript(transcript_path)
    if not entries:
        return

    write_snapshot(cwd, p, entries)


try:
    main()
except Exception:
    pass
PY
exit 0
