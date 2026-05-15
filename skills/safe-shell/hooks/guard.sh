#!/usr/bin/env bash
# guard.sh — PreToolUse hook for the `safe-shell` skill.
#
# Fires before every Bash tool call. Pattern-matches against a list
# of irreversible destructive commands and BLOCKS them — even when
# the user is running with --dangerously-skip-permissions / YOLO
# mode, where Anthropic's own permission prompts are bypassed.
#
# This is the difference between "Claude paused to ask" and "Claude
# rm -rf'd your home directory." Documented Dec 2025 home-directory
# deletion incidents (UpGuard / ClaudeLog postmortems) were the
# original motivation.
#
# Receives JSON on stdin (Claude Code's PreToolUse hook contract):
#   { "session_id", "tool_name": "Bash", "tool_input": {"command": "..."},
#     "permission_mode", "hook_event_name": "PreToolUse" }
#
# Response format (exit 0 + JSON on stdout):
#   { "hookSpecificOutput": {
#       "hookEventName": "PreToolUse",
#       "permissionDecision": "deny" | "allow",
#       "permissionDecisionReason": "..." } }
#
# Fails open on internal errors — we'd rather miss a block than
# crash and break the user's session.

set -u

payload=$(cat || true)
if [ -z "$payload" ]; then
  exit 0
fi

python3 - "$payload" <<'PY' || exit 0
import json, os, re, sys

# Patterns are tested in order. First match wins.
# Format: (severity, regex, human_message)
#   severity: "block"  — refuse outright, no override
#             "warn"   — let through but log a warning to stderr
PATTERNS = [
    # rm -rf against the filesystem root, home dir, or anything that
    # looks like it would wipe the world
    ("block",
     r"\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-rf|-fr|-Rf|-fR)\s+(/|~|~/|\$HOME|\${HOME}|/\*|\*)(\s|$)",
     "rm -rf against /, ~, or $HOME — irreversible filesystem wipe."),
    # rm -rf with --no-preserve-root anywhere
    ("block",
     r"\brm\s+.*--no-preserve-root",
     "rm with --no-preserve-root explicitly disables the safety net."),
    # rm -rf .  (current dir) is allowed (often intentional) BUT
    # rm -rf .git or .ssh wipes critical project / credential state
    ("block",
     r"\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-rf|-fr|-Rf|-fR)\s+\.git(\b|/|$)",
     "rm -rf .git destroys the entire git history of this repo."),
    ("block",
     r"\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-rf|-fr|-Rf|-fR)\s+.*\.ssh(\b|/|$)",
     "rm -rf against .ssh destroys SSH keys + known_hosts."),
    # git destructive ops — these can lose committed work
    ("block",
     r"\bgit\s+push\b[^;|&\n]*?\s--force\b",
     "git push --force can overwrite shared history. Run it yourself."),
    ("block",
     r"\bgit\s+push\b[^;|&\n]*?(?:^|\s)-f\b",
     "git push -f (short for --force) — same hazard. Run it yourself."),
    ("block",
     r"\bgit\s+reset\s+--hard\s+HEAD~",
     "git reset --hard HEAD~ silently discards committed work."),
    ("block",
     r"\bgit\s+clean\s+-[a-z]*f[a-z]*d|-d[a-z]*f",
     "git clean -fd removes untracked files irreversibly."),
    ("block",
     r"\bgit\s+branch\s+-D\s",
     "git branch -D force-deletes a branch even when unmerged."),
    # Disk-level destruction
    ("block",
     r"\b(mkfs(\.[a-z0-9]+)?|fdisk|parted)\s",
     "Disk formatting / partition table edits — refusing in a tool call."),
    ("block",
     r"\bdd\s+.*\bof=/dev/[sh]d",
     "dd writing to a raw disk device — refusing in a tool call."),
    # Permission nukes
    ("block",
     r"\bchmod\s+-R\s+(777|0?777)\s+/(\s|$)",
     "chmod -R 777 / opens up the entire filesystem to anyone."),
    ("block",
     r"\bchown\s+-R\s+.*\s+/(\s|$)",
     "chown -R against / changes ownership of the entire filesystem."),
    # Piping arbitrary remote scripts into a shell (curl-pipe-bash)
    ("block",
     r"\bcurl\s+[^|]*\bhttps?://[^\s|]+[^|]*\|\s*(sudo\s+)?(sh|bash|zsh)\b",
     "curl … | sh executes unaudited remote code. Download, inspect, then run."),
    ("block",
     r"\bwget\s+[^|]*\bhttps?://[^\s|]+[^|]*\|\s*(sudo\s+)?(sh|bash|zsh)\b",
     "wget … | sh executes unaudited remote code. Download, inspect, then run."),
    # Fork bomb
    ("block",
     r":\(\)\s*\{\s*:\|:\&\s*\}\s*;\s*:",
     "Fork bomb — would freeze the machine."),
    # Sudo + any of the above is even worse, but most cases are
    # already caught by the patterns above; this is a catch-all for
    # sudo rm against absolute paths under system dirs
    ("block",
     r"\bsudo\s+rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-rf|-fr)\s+/(usr|etc|var|bin|sbin|lib)(\s|/|$)",
     "sudo rm -rf inside a system dir — refusing."),
]


def load_payload():
    try:
        return json.loads(sys.argv[1])
    except Exception:
        return None


def emit_decision(decision, reason):
    out = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason,
        }
    }
    print(json.dumps(out))


def main():
    p = load_payload()
    if not p:
        return
    if p.get("tool_name") != "Bash":
        return  # not our concern
    cmd = p.get("tool_input", {}).get("command", "")
    if not isinstance(cmd, str) or not cmd.strip():
        return

    # Normalize whitespace for pattern matching (preserves chars but
    # collapses runs of spaces/tabs)
    norm = re.sub(r"\s+", " ", cmd.strip())

    for severity, pattern, message in PATTERNS:
        if re.search(pattern, norm):
            if severity == "block":
                reason = (
                    f"safe-shell (claude-papercuts) refused this command.\n"
                    f"Command:  {cmd}\n"
                    f"Reason:   {message}\n"
                    f"\nIf this is intentional, run it yourself in your "
                    f"own shell. safe-shell will not unblock destructive "
                    f"operations even in --dangerously-skip-permissions mode.\n"
                )
                emit_decision("deny", reason)
                return
    # No match → exit silently, Claude Code falls back to normal
    # permission logic


try:
    main()
except Exception:
    pass
PY
exit 0
