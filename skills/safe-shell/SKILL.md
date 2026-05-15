---
name: safe-shell
description: Block destructive Bash commands before Claude executes them — even in --dangerously-skip-permissions (YOLO) mode where Anthropic's own permission prompts are bypassed. Use this skill when the user runs /claude-papercuts:safe-shell, asks what safe-shell blocks, or wants to know why a command they expected was refused. A PreToolUse hook scans every Bash tool call against a list of irreversible patterns (rm -rf against / or ~, git push --force, git reset --hard HEAD~, mkfs, dd to /dev/sda, curl-pipe-bash, fork bombs) and refuses them with a structured explanation. Block decisions are visible to Claude so it can re-plan.
allowed-tools: Read
---

# safe-shell — refuse destructive Bash commands

**Fixes:** [UpGuard / ClaudeLog YOLO-mode postmortems (Dec 2025)](https://www.upguard.com/blog/claude-code-cybersecurity-risks) — documented home-directory deletions and `rm -rf /` from root when Claude Code ran with `--dangerously-skip-permissions` and no supervision.

## What this prevents

> *"A Claude Code session running with `--dangerously-skip-permissions`
> issued `rm -rf ~/` while attempting to 'clean up the project
> directory.' The user lost their entire home folder."* — Dec 2025
> postmortem

Anthropic's own permission prompt is the safety net for destructive
commands. In YOLO mode (`--dangerously-skip-permissions` or
`--permission-mode bypassPermissions`), that net is gone. `safe-shell`
sits *below* the permission layer and refuses a curated list of
irreversible operations *regardless* of permission mode.

## What gets blocked

| Category | Examples |
|---|---|
| Filesystem wipes | `rm -rf /`, `rm -rf ~/`, `rm -rf $HOME`, `rm --no-preserve-root` |
| Credential / git destruction | `rm -rf .git`, `rm -rf ~/.ssh`, `git reset --hard HEAD~3`, `git clean -fd`, `git branch -D` |
| Force-push | `git push --force`, `git push -f` (including `--force-with-lease`) |
| Disk-level | `mkfs`, `fdisk`, `parted`, `dd of=/dev/sd*` |
| Permission nukes | `chmod -R 777 /`, `chown -R … /` |
| Remote-code-exec | `curl … \| sh`, `wget … \| bash` |
| Fork bombs | `:(){ :\|:& };:` |

Commands that look destructive but operate on local project paths
(`rm -rf node_modules`, `rm -rf ./dist`, `git reset --hard HEAD`) are
allowed — the list is curated for catastrophic and irreversible
operations only.

## How it works (zero manual work for the user)

```
Claude wants to call Bash with command X
        │
        ▼
PreToolUse hook fires
        │
        ▼
Match X against the block-list regex set
        │
   ┌────┴────┐
   │         │
   ▼         ▼
No match    Match
   │         │
   ▼         ▼
exit 0      Emit { hookSpecificOutput.permissionDecision: "deny",
silent       permissionDecisionReason: "<explanation>" }
            on stdout. Claude Code refuses the call and feeds the
            reason back to Claude as an error.
```

## When you (the model) should invoke this skill manually

- User runs `/claude-papercuts:safe-shell`
- User asks "what does safe-shell block?"
- User asks why a Bash command was refused
- User asks how to safely run a destructive operation themselves

## Manual invocation procedure

1. Read `${CLAUDE_PLUGIN_ROOT}/skills/safe-shell/hooks/guard.sh` to
   see the current rule set.
2. Show the user the categories and examples in the table above.
3. If the user mentions a specific command, tell them whether it
   matches a block-list pattern (read the regex set, don't guess).
4. Never edit the rule set on your own. If the user wants to add or
   remove a rule, ask them to file an issue at
   `https://github.com/dhruba-datta/claude-papercuts/issues`.
5. If a command is blocked and the user genuinely wants to run it,
   tell them to run it in their own shell — safe-shell intentionally
   has no override flag.

## What this skill does NOT do

- **It is not a complete security layer.** It refuses the highest-
  hazard, most-irreversible commands. It does not stop crafted
  obfuscation (e.g. `r''m -rf /`, base64-encoded payloads, multi-step
  scripts). Treat it as a seatbelt, not a vault.
- **It does not log blocked attempts.** The block is visible to Claude
  via the hook reason; nothing is written to disk.
- **It does not warn before blocking.** No "are you sure" prompt — the
  command is refused outright. The user is expected to run intentional
  destructive operations in their own shell.
- **No override flag.** Even with `--dangerously-skip-permissions`, the
  block stands.

## Privacy

No network calls. Hook reads only the Bash command string passed by
Claude Code.

## Deprecation plan

If Anthropic ships a first-class destructive-command refusal layer
that survives `--dangerously-skip-permissions`, this skill becomes a
duplicate and gets deprecated in the next monthly release with the
date.
