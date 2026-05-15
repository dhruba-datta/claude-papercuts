# claude-papercuts

> Ten Claude Code skills that fix bugs Anthropic closed as "not planned."

[![CI](https://github.com/dhruba-datta/claude-papercuts/actions/workflows/test.yml/badge.svg)](https://github.com/dhruba-datta/claude-papercuts/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Made for Claude Code](https://img.shields.io/badge/made%20for-Claude%20Code-orange)](https://code.claude.com)

Anthropic's `claude-code` issue tracker has dozens of high-engagement
bug reports closed with `not planned`. This plugin ships one skill per
papercut. Each skill cites the GitHub issue it fixes — and gets
deprecated the day Anthropic actually fixes it.

**No telemetry.** This plugin makes zero network requests.

## Install

For now (pre-marketplace), clone and load locally:

```bash
git clone https://github.com/dhruba-datta/claude-papercuts ~/claude-papercuts
claude --plugin-dir ~/claude-papercuts
```

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
| 1 | [`unclear`](skills/unclear) | [`#39975`](https://github.com/anthropics/claude-code/issues/39975) — `/clear` has no undo | ✅ |
| 2 | [`done-prover`](skills/done-prover) | [`#5052`](https://github.com/anthropics/claude-code/issues/5052), [`#10628`](https://github.com/anthropics/claude-code/issues/10628), [`#20350`](https://github.com/anthropics/claude-code/issues/20350) — Claude lies about completion | ✅ |
| 3 | [`skill-budget`](skills/skill-budget) | [`#30387`](https://github.com/anthropics/claude-code/issues/30387), [`#34648`](https://github.com/anthropics/claude-code/issues/34648), [`#16575`](https://github.com/anthropics/claude-code/issues/16575) — skills silently vanish past the ~15K char budget | ✅ |
| 4 | [`amnesia-fix`](skills/amnesia-fix) | [`#14227`](https://github.com/anthropics/claude-code/issues/14227), [`#27298`](https://github.com/anthropics/claude-code/issues/27298), [`#43696`](https://github.com/anthropics/claude-code/issues/43696) — no cross-session memory | ✅ |
| 5 | [`token-x-ray`](skills/token-x-ray) | [`#39686`](https://github.com/anthropics/claude-code/issues/39686) — auto-injected plugins waste 6k+ tokens silently | ✅ |
| 6 | [`compact-guard`](skills/compact-guard) | [`#24686`](https://github.com/anthropics/claude-code/issues/24686), [`#26061`](https://github.com/anthropics/claude-code/issues/26061) — plan-mode state lost on compact | ✅ |
| 7 | [`safe-shell`](skills/safe-shell) | (UpGuard/ClaudeLog postmortems) — YOLO `rm -rf` incidents | ✅ |
| 8 | `onboard` | (Medium/MindStudio reports) — new users install too many skills and churn | ⏳ |
| 9 | [`skill-doctor`](skills/skill-doctor) | Root cause of [`#30387`](https://github.com/anthropics/claude-code/issues/30387) — descriptions overlap with training | ✅ |
| 10 | `subagent-broker` | [`#4182`](https://github.com/anthropics/claude-code/issues/4182), [`#5528`](https://github.com/anthropics/claude-code/issues/5528), [`#19077`](https://github.com/anthropics/claude-code/issues/19077) — subagent delegation broken | ⏳ |

Full per-issue details in [`docs/issues.md`](docs/issues.md). One new
papercut drops on the 1st of every month.

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
  "done" gets re-verified by the relevant skill.
- **Refuse before warning.** Risky commands block by default, not
  prompt-and-continue.
- **No emoji in commands.** Read the docs, run the command, see the
  output. No theatrics.

## Testing

```bash
bash tests/run-all.sh
```

235 tests covering plugin schema, all Stop hooks' behavior
(snapshot pruning, claim detection, journal append/load),
audit.py discovery + budget logic, regex extraction (bulleted
and inline), unicode/control-char fidelity, concurrent
invocations, and shellcheck on the shell scripts.
CI runs the same suite on every push and PR.

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
