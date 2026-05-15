---
name: unclear
description: Restore Claude Code conversation context after an accidental /clear. Use this skill when the user types /claude-papercuts:unclear, mentions accidentally clearing the conversation, asks to undo /clear, or wants to recover lost context from a recent session. Reads the most recent automatic snapshot from .papercuts/snapshots/ and reconstructs what was being discussed.
allowed-tools: Bash(ls:*), Bash(cat:*), Bash(head:*), Read
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
3. When the user invokes this skill (via `/claude-papercuts:unclear` or
   by mentioning a recovery phrase), it reads the most recent snapshot
   and reconstructs a summary of what was being worked on so work can
   continue cleanly.

## When you (the model) should invoke this skill

Auto-invoke when the user:

- Runs the `/claude-papercuts:unclear` slash command
- Says "I accidentally cleared the conversation"
- Says "can you remember what we were working on"
- Says "undo /clear"
- Asks to recover or restore prior context

## Recovery procedure

When invoked, follow these steps exactly.

### Step 1 — Locate snapshots

Run this in the shell:

```bash
ls -1t .papercuts/snapshots/*.jsonl 2>/dev/null | head -5
```

If the output is empty, the Stop hook has not run yet in this project.
Tell the user:

> No snapshots found in `.papercuts/snapshots/`. The Stop hook writes
> a snapshot at the end of every assistant turn, so a brand-new
> session has no recovery point. Future sessions in this project will
> be recoverable.

Then stop.

### Step 2 — Read the newest snapshot

Use the Read tool to load the most recent snapshot file (the first
line of the `ls` output). It's a JSONL file where each line is one
JSON object representing a turn in the prior conversation. The schema
is roughly:

```jsonc
{"type": "user" | "assistant" | "summary" | "tool_use" | "tool_result",
 "message": {"role": "...", "content": [...]},
 "timestamp": "ISO-8601",
 ...}
```

Different Claude Code versions may use slightly different schemas. Be
permissive — read whatever's there.

### Step 3 — Summarize the prior conversation

Extract from the snapshot:

- **What was being worked on** — read the first 2-3 user messages and
  the last assistant message to bracket the topic
- **Files being edited** — scan tool_use entries for `Edit`, `Write`,
  `Read` and collect unique paths
- **Recent decisions** — look for lines in assistant messages starting
  with "Decision:", "Next:", "Blocker:", or explicit conclusions
- **Anything the user explicitly asked you not to do** — these are
  often the most important signals to preserve

### Step 4 — Present the recap

Output exactly this format (terminal-friendly, no emoji, no
exclamation marks):

```
─── /unclear: snapshot restored ───
Source: <relative path to snapshot file>
Timestamp: <ISO-8601 from the snapshot filename, decoded>
Turns recovered: <count>

Last topic
  <one-sentence summary>

Files in play
  <path 1>
  <path 2>
  ...

Recent decisions
  • <decision 1>
  • <decision 2>
  • <decision 3>

Picking up from
  "<verbatim final user message, or final assistant turn if no
   pending user turn>"
─────────────────────────────────
```

### Step 5 — Wait

After printing the recap, do not take any further action. Wait for the
user to confirm or redirect. They may want to:

- Resume exactly where they left off (most common)
- Pick one of the listed decisions to revisit
- Discard the recap and start fresh

Match the user's intent on the next turn. Do not assume.

## Edge cases

- **Multiple snapshots in the same UTC second**: pick the
  alphabetically last one (timestamps are UTC and lexicographically
  ordered).
- **Snapshot is empty or malformed JSON**: try the next-newest. If all
  recent snapshots are unreadable, tell the user honestly and stop.
- **Snapshot is from a different cwd than the current one**: still
  read it, but flag in the recap: "Note: snapshot was taken from
  `<other path>` — context may not match this directory."

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

Defaults are sensible. Most users never need to touch this.

## What this skill does NOT do

- It does not literally restore Claude's internal conversation history.
  Claude Code's transcript is internal state. The skill gives a
  human-readable + Claude-readable recap that lets the conversation
  continue from a known good point.
- It does not auto-trigger on `/clear`. The Stop hook simply
  snapshots every turn so a snapshot is always available before the
  next `/clear`.
- It does not store anything outside `.papercuts/snapshots/` in your
  project. Add `.papercuts/` to `.gitignore` if not already.

## Privacy

The Stop hook writes the transcript to a local file in your project's
`.papercuts/` directory. No network calls. No telemetry. If you don't
want local persistence either, disable the hook in your Claude
settings — the slash command will simply report "no snapshots found."
