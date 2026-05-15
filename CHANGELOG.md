# Changelog

All notable changes to claude-papercuts are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning is [SemVer](https://semver.org/).

## [0.1.0] — 2026-05-16

Initial public release. Ten Claude Code skills, each fixing a specific
issue Anthropic closed as "not planned" — every skill cites the GitHub
issue it addresses.

### Added — the 10 skills

| # | Skill | Fixes |
|---|---|---|
| 1 | `unclear` | [`#39975`](https://github.com/anthropics/claude-code/issues/39975) — `/clear` has no undo |
| 2 | `done-prover` | [`#5052`](https://github.com/anthropics/claude-code/issues/5052), [`#10628`](https://github.com/anthropics/claude-code/issues/10628), [`#20350`](https://github.com/anthropics/claude-code/issues/20350) — Claude lies about completion |
| 3 | `skill-budget` | [`#30387`](https://github.com/anthropics/claude-code/issues/30387), [`#34648`](https://github.com/anthropics/claude-code/issues/34648), [`#16575`](https://github.com/anthropics/claude-code/issues/16575) — skills silently vanish past the ~15K char budget |
| 4 | `amnesia-fix` | [`#14227`](https://github.com/anthropics/claude-code/issues/14227), [`#27298`](https://github.com/anthropics/claude-code/issues/27298), [`#43696`](https://github.com/anthropics/claude-code/issues/43696) — no cross-session memory |
| 5 | `token-x-ray` | [`#39686`](https://github.com/anthropics/claude-code/issues/39686) — auto-injected plugins waste 6k+ tokens silently |
| 6 | `compact-guard` | [`#24686`](https://github.com/anthropics/claude-code/issues/24686), [`#26061`](https://github.com/anthropics/claude-code/issues/26061) — plan-mode state lost on `/compact` |
| 7 | `safe-shell` | UpGuard / ClaudeLog YOLO-mode postmortems — `rm -rf ~/` incidents |
| 8 | `onboard` | Medium / MindStudio onboarding-churn reports |
| 9 | `skill-doctor` | Root cause of [`#30387`](https://github.com/anthropics/claude-code/issues/30387) — descriptions overlap with training |
| 10 | `subagent-broker` | [`#4182`](https://github.com/anthropics/claude-code/issues/4182), [`#5528`](https://github.com/anthropics/claude-code/issues/5528), [`#19077`](https://github.com/anthropics/claude-code/issues/19077) — subagent delegation broken |

### Plumbing

- Five Claude Code hook types wired: `Stop`, `SessionStart`, `PreCompact`,
  `PreToolUse`, and Stop-chain composition.
- Five standalone Python scripts: `audit.py` (skill-budget),
  `audit.py` (token-x-ray), `lint.py` (skill-doctor), `recommend.py`
  (onboard), `templates.py` (subagent-broker).
- 271 tests in `tests/run-all.sh`, all passing locally and in CI.
- `shellcheck` clean on every shell script.
- vhs-rendered GIF demos for each of the 10 skills.
- Zero network calls. Every skill is local.

### Install

```bash
git clone https://github.com/dhruba-datta/claude-papercuts ~/claude-papercuts
claude --plugin-dir ~/claude-papercuts
```

Skills are namespaced — invoke as `/claude-papercuts:<skill>`.

[0.1.0]: https://github.com/dhruba-datta/claude-papercuts/releases/tag/v0.1.0
