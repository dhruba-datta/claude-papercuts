---
name: unclear
description: Restore Claude Code conversation context after an accidental /clear. Use this skill when the user types /unclear, mentions accidentally clearing the conversation, asks to undo /clear, or wants to recover lost context from a recent session. Reads the most recent automatic snapshot from .papercuts/snapshots/ and reconstructs what was being discussed.
---

# unclear — undo `/clear`

**Fixes:** [`anthropics/claude-code#39975`](https://github.com/anthropics/claude-code/issues/39975)
(open feature request, no fix on roadmap)

## What this prevents

> "Muscle memory, typo, or misclick. The session is gone. There is no
> undo, no confirmation prompt, and no way to get back."
> — issue #39975

## How it works

1. A `Stop` hook runs at the end of every assistant turn and writes a
   snapshot of the current conversation transcript to
   `.papercuts/snapshots/<timestamp>.jsonl` (project-local, gitignored).
2. The 5 most recent snapshots are kept; older ones are pruned.
3. When the user runs `/unclear` (or mentions wanting to recover
   context), this skill reads the most recent snapshot and reconstructs
   a summary of what was being worked on so Claude can pick up where
   things left off.

## When to invoke this skill

Auto-invoke when the user:

- Runs the `/unclear` slash command
- Says "I accidentally cleared the conversation"
- Says "can you remember what we were working on"
- Says "undo /clear"
- Asks to recover or restore prior context

## Recovery procedure

When invoked (either via the `/unclear` slash command or because the
user mentioned a relevant phrase):

1. List files matching `.papercuts/snapshots/*.jsonl` in the project
   working directory (sorted by mtime, newest first).
2. If no snapshots exist, tell the user:
   > "No snapshots found. The Stop hook may not have run yet — this
   > skill snapshots at the end of each assistant turn, so a brand-new
   > session has no recovery point. Future sessions will."
3. Otherwise, read the newest snapshot file. It's a JSONL file matching
   the format of Claude Code's transcript files.
4. Extract the last 10 messages (user + assistant). Summarize:
   - What was being worked on
   - The most recent decisions or "Next:" / "Blocker:" lines
   - Any files that were being edited (look for `tool_use_id` events
     with `Edit` or `Write` tools)
5. Present a recap to the user in this format:

   ```
   Restored from snapshot: <relative path>
   Timestamp: <ISO 8601>
   Last topic: <one sentence>

   Last 3 decisions:
   - <decision 1>
   - <decision 2>
   - <decision 3>

   Files being edited:
   - <path>
   - <path>

   Ready to continue.
   ```

6. Wait for the user to confirm before doing any further action.

## Configuration

Optional `.papercuts/config.json` in the project root:

```json
{
  "unclear": {
    "snapshot_retention": 5,
    "snapshot_dir": ".papercuts/snapshots"
  }
}
```

## What this skill does NOT do

- It does not literally restore Claude's internal conversation history.
  Claude Code's transcript is internal state. The skill gives you a
  human-readable + Claude-readable recap that lets the conversation
  continue from a known good point.
- It does not auto-trigger `/clear`. The Stop hook simply snapshots
  every turn so a snapshot is always available.
- It does not store anything outside `.papercuts/snapshots/` in your
  project. Add `.papercuts/` to `.gitignore` if not already.

## Privacy

The Stop hook writes the transcript to a local file in your project's
`.papercuts/` directory. No network calls. No telemetry. If you don't
want any local persistence either, disable the hook in your Claude
settings — the slash command will simply report "no snapshots found."
