# claude-papercuts

> Ten Claude Code skills that fix bugs Anthropic closed as "not planned."

Anthropic's `claude-code` issue tracker has dozens of high-engagement
bug reports closed with `not planned`. This plugin ships one skill per
papercut. Each skill cites the GitHub issue it fixes.

**No telemetry.** This plugin makes zero network requests. We don't
count installs, runs, or anything else. The only network traffic on
your machine is Claude itself.

## Install

For now (pre-marketplace), clone and load locally:

```bash
git clone https://github.com/dhruba-datta/claude-papercuts ~/claude-papercuts
claude --plugin-dir ~/claude-papercuts
```

Or convert your existing `.claude/` config — see the
[Anthropic docs](https://code.claude.com/docs/en/plugins#convert-existing-configurations-to-plugins).

Once a marketplace is set up (planned):

```bash
/plugin marketplace add dhruba-datta/claude-papercuts
/plugin install claude-papercuts
```

Skills in this plugin are namespaced. Invoke as
`/claude-papercuts:<skill>`.

## The papercuts

| # | Skill | Fixes | Status |
|---|---|---|---|
| 1 | [`unclear`](skills/unclear) | [`#39975`](https://github.com/anthropics/claude-code/issues/39975) — `/clear` has no undo | shipped |
| 2 | `done-prover` | [`#5052`](https://github.com/anthropics/claude-code/issues/5052), [`#10628`](https://github.com/anthropics/claude-code/issues/10628), [`#20350`](https://github.com/anthropics/claude-code/issues/20350) — Claude lies about completion | next |
| 3 | `skill-budget` | [`#30387`](https://github.com/anthropics/claude-code/issues/30387), [`#34648`](https://github.com/anthropics/claude-code/issues/34648), [`#16575`](https://github.com/anthropics/claude-code/issues/16575) — skills silently vanish past the ~15K char budget | next |
| 4 | `amnesia-fix` | [`#14227`](https://github.com/anthropics/claude-code/issues/14227), [`#27298`](https://github.com/anthropics/claude-code/issues/27298), [`#43696`](https://github.com/anthropics/claude-code/issues/43696) — no cross-session memory | planned |
| 5 | `token-x-ray` | [`#39686`](https://github.com/anthropics/claude-code/issues/39686) — auto-injected plugins waste 6k+ tokens silently | planned |
| 6 | `compact-guard` | [`#24686`](https://github.com/anthropics/claude-code/issues/24686), [`#26061`](https://github.com/anthropics/claude-code/issues/26061) — plan-mode state lost on compact | planned |
| 7 | `safe-shell` | (UpGuard/ClaudeLog postmortems) — YOLO `rm -rf` incidents | planned |
| 8 | `onboard` | (Medium/MindStudio reports) — new users install too many skills and churn | planned |
| 9 | `skill-doctor` | Root cause of [`#30387`](https://github.com/anthropics/claude-code/issues/30387) — descriptions overlap with training | planned |
| 10 | `subagent-broker` | [`#4182`](https://github.com/anthropics/claude-code/issues/4182), [`#5528`](https://github.com/anthropics/claude-code/issues/5528), [`#19077`](https://github.com/anthropics/claude-code/issues/19077) — subagent delegation broken | planned |

## What this is, in one paragraph

Most Claude Code "awesome skills" repos are append-only lists of 1,000+
SaaS wrappers. This one is the opposite — ten skills, each one a
receipt for a specific issue Anthropic decided not to fix. Every
README starts with the issue number. When Anthropic eventually ships
a real fix, the corresponding skill becomes a no-op and gets
deprecated with a date. We read the closed-as-not-planned issues so
you don't have to.

## Voice & conventions

- **Trust, then verify.** Every claim Claude makes that something is
  "done" gets re-verified.
- **Refuse before warning.** Risky commands block by default, not
  prompt-and-continue.
- **No emoji in commands.** Read the docs, run the command, see the
  output. No theatrics.

## Contributing

The monthly papercut drops on the 1st of each month. To propose the
next one, open an issue with:

1. A link to the Anthropic GitHub issue it would fix (must be a real
   number, not a vibe)
2. The reproducer steps
3. A one-paragraph sketch of the skill that would address it

If the issue has been open for >60 days or closed-as-not-planned with
>20 reactions, it's a strong candidate.

## License

MIT. See [LICENSE](LICENSE).

## Acknowledgments

- The [`anthropics/claude-code`](https://github.com/anthropics/claude-code)
  community whose issues are this project's bibliography
- [`obra/superpowers`](https://github.com/obra/superpowers) for the
  methodology-as-skill framing
- The 16 verified issues that anchor this work — full list and
  per-skill mapping in [`docs/issues.md`](docs/issues.md)
