# `unclear` — undo `/clear`

**Fixes:** [`anthropics/claude-code#39975`](https://github.com/anthropics/claude-code/issues/39975) (OPEN as of 2026-05-15)

## What this prevents

> "Muscle memory, typo, or misclick. The session is gone. There is no
> undo, no confirmation prompt, and no way to get back."
> — issue #39975

## How it works

```
End of every assistant turn
        │
        ▼
   Stop hook fires
        │
        ▼
Transcript snapshotted to
.papercuts/snapshots/<UTC timestamp>.jsonl
        │
        ▼
Oldest snapshots pruned (keep 5)


User types /clear by mistake
        │
        ▼
User types /unclear
        │
        ▼
Slash command reads newest snapshot
        │
        ▼
Reconstructs recap: topic, files, decisions
        │
        ▼
User picks up where they left off
```

## What's installed

| Path | What |
|---|---|
| `skills/unclear/SKILL.md` | Skill metadata for Claude's auto-invocation |
| `skills/unclear/hooks/snapshot.sh` | Stop hook that snapshots each turn |
| `commands/unclear.md` | The `/unclear` slash command implementation |

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

## Trying it locally

After installing the plugin:

```bash
# Start a Claude Code session, do some work
claude

# At the end of any assistant turn, verify the snapshot landed
ls -1t .papercuts/snapshots/ | head -3

# Test recovery (in a fresh session)
claude
/unclear
```

## Privacy

Snapshots are written to your project's local `.papercuts/snapshots/`
directory. Nothing is sent over the network. The directory is in the
default `.gitignore` for any project that uses this plugin.

If you don't want any local persistence, remove the Stop hook entry
from your settings — the `/unclear` command will simply report no
snapshots were found.

## Known limitations

- Snapshots capture the transcript file at the moment the hook runs. If
  Claude's internal state (e.g., open tool calls) diverges from the
  written transcript, the snapshot reflects the written version only.
- The recap is a *summary* of what was being worked on, not a literal
  state restore. Claude's internal conversation context is not
  re-populated — but in practice the recap is sufficient to resume
  cleanly.
- Snapshots are project-local, not global. If you accidentally `/clear`
  while in a different directory than where the prior work happened,
  the snapshot is in the original project's directory.

## Deprecation plan

If Anthropic ships a real fix for [#39975](https://github.com/anthropics/claude-code/issues/39975)
(e.g., a built-in `/unclear` or a confirmation prompt on `/clear`),
this skill becomes a no-op. We'll update this README with the date and
deprecate the skill in the next monthly release.
