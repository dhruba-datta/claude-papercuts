#!/usr/bin/env bash
# journal-append.sh — Stop hook for the `amnesia-fix` skill.
#
# Runs at the end of every assistant turn. Reads the transcript,
# extracts: files touched (from Edit/Write tool uses), decisions /
# next steps / blockers (from lines in the last assistant message
# starting with "Decision:", "Next:", "Blocker:"), and the topic
# (first user message of this turn). Appends a compact entry to
# <cwd>/.papercuts/journal.md.
#
# Receives JSON on stdin (Claude Code's Stop hook contract):
#   { "session_id", "transcript_path", "cwd", "hook_event_name", "stop_reason" }
#
# Fails open: never blocks the user on internal errors.
# Per-entry cap: ~500 chars. Per section: 5 items, 200 chars each.

set -u

payload=$(cat || true)
if [ -z "$payload" ]; then
  exit 0
fi

python3 - "$payload" <<'PY' || exit 0
import json, os, re, sys, subprocess
from datetime import datetime, timezone

MAX_ITEMS_PER_SECTION = 5
MAX_ITEM_CHARS = 200
MAX_ENTRY_CHARS = 500

DECISION_RE = re.compile(r"(?:decision|decided)\s*[:\-]\s*(.+?)$", re.IGNORECASE)
NEXT_RE     = re.compile(r"(?:next(?:\s*step)?|todo)\s*[:\-]\s*(.+?)$", re.IGNORECASE)
BLOCKER_RE  = re.compile(r"(?:blocker|blocked\s*by)\s*[:\-]\s*(.+?)$", re.IGNORECASE)


def load_payload():
    try:
        return json.loads(sys.argv[1])
    except Exception:
        return None


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
            return extract_text(msg)
    return ""


def find_first_user_text(entries):
    """The topic — first user message in this turn (or whole session if short)."""
    for entry in entries:
        msg = entry.get("message", {})
        role = msg.get("role") if isinstance(msg, dict) else None
        if entry.get("type") == "user" or role == "user":
            content = msg.get("content", "") if isinstance(msg, dict) else ""
            if isinstance(content, str) and content.strip():
                return content.strip()
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get("type") == "text":
                        return c.get("text", "").strip()
    return ""


def find_files_touched(entries):
    files = []
    seen = set()
    for entry in entries:
        msg = entry.get("message", {})
        content = msg.get("content") if isinstance(msg, dict) else None
        if isinstance(content, list):
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "tool_use":
                    name = block.get("name", "")
                    if name in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
                        path = block.get("input", {}).get("file_path", "")
                        if path and path not in seen:
                            seen.add(path)
                            files.append(path)
    return files


def extract_marked(text, regex):
    """Find all 'Marker: text' instances, handling both bulleted lists and
    inline prose. Splits on newlines AND sentence boundaries, strips bullet
    markers, then matches the regex at the start of each chunk."""
    found = []
    seen = set()
    if not text:
        return found
    # Split on newlines and sentence terminators
    chunks = re.split(r"(?:\n|(?<=[.!?])\s+)", text)
    for chunk in chunks:
        chunk = chunk.strip().lstrip("-*•").strip()
        if not chunk:
            continue
        m = regex.match(chunk)
        if m:
            item = m.group(1).strip().rstrip(".,;!?")
            key = item.lower()
            if item and key not in seen:
                seen.add(key)
                found.append(item)
    return found


def cap(items, max_items=MAX_ITEMS_PER_SECTION, max_chars=MAX_ITEM_CHARS):
    out = []
    for it in items[:max_items]:
        if len(it) > max_chars:
            it = it[: max_chars - 1] + "…"
        out.append(it)
    return out


def git_branch(cwd):
    try:
        r = subprocess.run(
            ["git", "-C", cwd, "branch", "--show-current"],
            capture_output=True, text=True, timeout=2,
        )
        b = r.stdout.strip()
        return b if b else None
    except Exception:
        return None


def short_topic(user_text, max_chars=80):
    if not user_text:
        return "(no prompt)"
    one = " ".join(user_text.split())
    if len(one) > max_chars:
        one = one[: max_chars - 1] + "…"
    return one


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

    assistant_text = find_last_assistant_text(entries)
    user_text = find_first_user_text(entries)

    decisions = cap(extract_marked(assistant_text, DECISION_RE))
    nexts = cap(extract_marked(assistant_text, NEXT_RE))
    blockers = cap(extract_marked(assistant_text, BLOCKER_RE))
    files = cap(find_files_touched(entries))

    # Skip if there's literally nothing worth journalling
    if not (decisions or nexts or blockers or files or user_text):
        return

    branch = git_branch(cwd) or "no-branch"
    topic = short_topic(user_text)
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    lines = [f"## {ts} | {branch} | {topic}"]
    if files:
        lines.append("- Files: " + ", ".join(files))
    if decisions:
        lines.append("- Decisions:")
        for d in decisions:
            lines.append(f"  - {d}")
    if nexts:
        lines.append("- Next:")
        for n in nexts:
            lines.append(f"  - {n}")
    if blockers:
        lines.append("- Blockers:")
        for b in blockers:
            lines.append(f"  - {b}")

    entry = "\n".join(lines)
    # Cap total entry size — protect against transcripts with huge content
    if len(entry) > MAX_ENTRY_CHARS:
        entry = entry[: MAX_ENTRY_CHARS - 1] + "…"

    journal_dir = os.path.join(cwd, ".papercuts")
    os.makedirs(journal_dir, exist_ok=True)
    journal_path = os.path.join(journal_dir, "journal.md")

    try:
        with open(journal_path, "a", encoding="utf-8") as f:
            f.write(entry + "\n\n")
    except Exception:
        pass


try:
    main()
except Exception:
    pass
PY
exit 0
