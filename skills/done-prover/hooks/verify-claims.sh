#!/usr/bin/env bash
# verify-claims.sh — Stop hook for the `done-prover` skill.
#
# Runs at the end of every assistant turn. If the assistant's final
# message claims tests are passing, scan the recent transcript for the
# actual tool_result of the most recent test run and look for failure
# signals (FAIL, ERROR, "\d+ failed", etc.). If a discrepancy is
# detected, emit JSON to stdout with decision=block + a verdict so
# Claude is forced to address the lie before stopping.
#
# Hook payload (stdin):
#   { "session_id", "transcript_path", "cwd", "hook_event_name", "stop_reason" }
#
# Behavior:
#   - No claim phrase → silent exit 0
#   - Claim phrase but no recent test output in transcript → silent
#   - Claim phrase + clean test output → silent (the claim was honest)
#   - Claim phrase + dirty test output → JSON block + write verdict to
#     .papercuts/proofs/<timestamp>.md
#
# Never blocks the user on internal errors. Fails open.

set -u

# Read stdin payload
payload=$(cat || true)
if [ -z "$payload" ]; then
  exit 0
fi

# Hand off to Python — bash regex + JSONL parsing is too fragile.
# Python 3 ships with macOS and every Linux distro Claude Code runs on.
python3 - "$payload" <<'PY' || exit 0
import json, os, re, sys
from datetime import datetime, timezone

# Patterns that indicate the assistant claimed test success.
# Conservative — we want this to be specific enough to avoid false
# positives on generic "I'm done" statements.
CLAIM_PATTERNS = [
    r"\ball tests? (pass|passed|passing|are passing|are green)\b",
    r"\ball checks (pass|passed|passing)\b",
    r"\beverything (passes|passed|is passing|is green)\b",
    r"\b(?:all )?(\d+) tests? (pass|passed|passing)\b",
    r"\b(\d+)/(\d+) tests? (pass|passed|passing)\b",
    r"\btests? all clean\b",
    r"\ball green\b",
]

# Patterns that indicate a failure in test output.
FAILURE_PATTERNS = [
    (r"\b(\d+) failed\b",          "{} test(s) failed"),
    (r"\bFAILED\b",                 "FAILED marker present"),
    (r"\bFAIL\b(?!.*\bPASS\b)",     "FAIL marker present"),
    (r"\bERROR\b",                  "ERROR marker present"),
    (r"AssertionError",             "AssertionError raised"),
    (r"ImportError",                "ImportError raised"),
    (r"\bTest.*failed\b",           "Test failure"),
    (r"\b(\d+) error[s]?\b",        "{} error(s)"),
]

# Patterns that indicate skipped/xfailed tests — informational, not a lie.
SKIP_PATTERNS = [
    (r"\b(\d+) skipped\b",    "{} skipped"),
    (r"\b(\d+) xfailed\b",    "{} xfailed"),
    (r"\b(\d+) deselected\b", "{} deselected"),
]


def load_payload():
    try:
        return json.loads(sys.argv[1])
    except Exception:
        return None


def read_transcript(path):
    """Return list of JSONL entries, or [] on any error."""
    try:
        with open(path, encoding="utf-8") as f:
            return [json.loads(line) for line in f if line.strip()]
    except Exception:
        return []


def extract_text_from_message(msg):
    """Pull plain text from an assistant message (which may have a list of content blocks)."""
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
    """Walk entries in reverse, return the text of the most recent assistant turn."""
    for entry in reversed(entries):
        if entry.get("type") == "assistant":
            return extract_text_from_message(entry.get("message", {}))
        # Some schemas put role inside message directly without the wrapper type
        msg = entry.get("message")
        if isinstance(msg, dict) and msg.get("role") == "assistant":
            return extract_text_from_message(msg)
    return ""


def detect_claim(text):
    """Return the matched claim phrase, or None."""
    if not text:
        return None
    for pat in CLAIM_PATTERNS:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            return m.group(0)
    return None


def find_recent_tool_results(entries, limit=15):
    """Return text content of the most recent N tool_result entries."""
    results = []
    for entry in reversed(entries):
        if entry.get("type") == "tool_result" or entry.get("type") == "user":
            content = entry.get("content") or entry.get("message", {}).get("content")
            if isinstance(content, str):
                results.append(content)
            elif isinstance(content, list):
                for block in content:
                    if isinstance(block, dict):
                        if block.get("type") == "tool_result":
                            inner = block.get("content", "")
                            if isinstance(inner, str):
                                results.append(inner)
                            elif isinstance(inner, list):
                                for sub in inner:
                                    if isinstance(sub, dict) and sub.get("type") == "text":
                                        results.append(sub.get("text", ""))
        if len(results) >= limit:
            break
    return results


def detect_failures(text):
    """Return list of (label, count_or_none) tuples describing failures found."""
    findings = []
    for pat, template in FAILURE_PATTERNS:
        m = re.search(pat, text)
        if m:
            try:
                count = m.group(1)
                findings.append(template.format(count))
            except (IndexError, ValueError):
                findings.append(template)
    return findings


def detect_skips(text):
    findings = []
    for pat, template in SKIP_PATTERNS:
        m = re.search(pat, text)
        if m:
            try:
                count = m.group(1)
                findings.append(template.format(count))
            except (IndexError, ValueError):
                findings.append(template)
    return findings


def write_verdict_artifact(cwd, claim, evidence, failures, skips):
    """Persist a markdown verdict file. Best-effort; never fatal."""
    try:
        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        proof_dir = os.path.join(cwd, ".papercuts", "proofs")
        os.makedirs(proof_dir, exist_ok=True)
        path = os.path.join(proof_dir, f"{ts}.md")
        body = [
            f"# done-prover verdict — {ts}",
            "",
            f"**Claim:** \"{claim}\"",
            "",
            "**Failure signals in recent test output:**",
        ]
        for f in failures:
            body.append(f"- {f}")
        if skips:
            body.append("")
            body.append("**Skipped/xfailed signals:**")
            for s in skips:
                body.append(f"- {s}")
        body.append("")
        body.append("**Evidence (excerpt):**")
        body.append("```")
        body.append(evidence[:1500])
        body.append("```")
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(body))
        return path
    except Exception:
        return None


def emit_block(reason):
    """Emit JSON to stdout; this is the contract for Stop hooks per Claude Code docs."""
    print(json.dumps({"decision": "block", "reason": reason}))
    sys.exit(0)


def main():
    p = load_payload()
    if not p:
        return
    transcript_path = p.get("transcript_path")
    cwd = p.get("cwd")
    if not transcript_path or not os.path.isfile(transcript_path):
        return
    if not cwd or not os.path.isdir(cwd):
        cwd = os.getcwd()

    entries = read_transcript(transcript_path)
    if not entries:
        return

    text = find_last_assistant_text(entries)
    claim = detect_claim(text)
    if not claim:
        return

    tool_results = find_recent_tool_results(entries, limit=8)
    if not tool_results:
        return

    # Scan results newest-first; surface the FIRST result with failures.
    for result in tool_results:
        failures = detect_failures(result)
        if failures:
            skips = detect_skips(result)
            artifact = write_verdict_artifact(cwd, claim, result, failures, skips)
            failure_summary = "; ".join(failures)
            artifact_line = f"\nFull verdict saved to: {artifact}" if artifact else ""
            reason = (
                "done-prover detected a possible false completion claim.\n\n"
                f"You said: \"{claim}\"\n"
                f"But the most recent test output shows: {failure_summary}\n\n"
                "Please re-run the failing tests and address the issues before "
                "declaring this complete."
                f"{artifact_line}"
            )
            emit_block(reason)

    # Claim was made but no failures detected in recent output — silent (the claim is honest enough).


try:
    main()
except Exception:
    # Fail open: never block the user on a hook bug.
    pass
PY
exit 0
