# tests

Run from the repo root:

```bash
bash tests/run-all.sh
```

Or directly:

```bash
./tests/run-all.sh
```

The runner is dependency-light:

- **bash** + **python3** are required (both ship with macOS and every
  Linux distro Claude Code runs on)
- **shellcheck** is optional — installed it bumps the test count from
  43 to 45. `brew install shellcheck` on macOS, `apt-get install
  shellcheck` on Debian/Ubuntu.

CI runs the same script on every push and PR. See
[`.github/workflows/test.yml`](../.github/workflows/test.yml).

## What's tested

| Section | Tests |
|---|---|
| Artifact existence + permissions | 11 |
| JSON validity | 2 |
| `plugin.json` schema | 1 |
| `hooks/hooks.json` schema | 1 |
| `SKILL.md` frontmatter | 1 |
| Snapshot hook — happy path | 4 |
| Snapshot hook — error handling | 9 |
| Snapshot hook — retention pruning | 6 |
| Snapshot hook — content fidelity | 3 |
| Snapshot hook — concurrent invocations | 1 |
| Static analysis — shellcheck | 2 (skipped if shellcheck missing) |
| README + docs sanity | 4 |

Every test runs in its own tempdir and cleans up on exit. Re-runnable
without state pollution.

## Adding a new test

```bash
# Inside an appropriate `section`:
W=$(fresh_workspace)
# ... set up state ...
PAYLOAD='{"transcript_path":"...","cwd":"..."}'
EXIT=$(run_hook "$PAYLOAD" "$W")
[ "$EXIT" = "0" ] && pass "your test name" || fail "your test name"
cleanup; cleanup_dir=""
```

Follow the existing conventions:
- One test = one `pass`/`fail` call
- Always clean up the workspace before the next test
- Tests must work whether or not `shellcheck` is installed
