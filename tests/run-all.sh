#!/usr/bin/env bash
# tests/run-all.sh — exhaustive test suite for claude-papercuts.
#
# Runs every test we know how to run, locally. Designed to be safe to
# invoke repeatedly. Cleans up after itself. Exits non-zero on any
# failure so it can wire straight into CI.

set -u

# Resolve repo root regardless of where this is invoked from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO/skills/unclear/hooks/snapshot.sh"
DONE_HOOK="$REPO/skills/done-prover/hooks/verify-claims.sh"
AUDIT="$REPO/skills/skill-budget/audit.py"

# Colors (disable if not a TTY)
if [ -t 1 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; RESET=""
fi

PASS=0
FAIL=0
SKIP=0
FAILED_TESTS=()

pass() { PASS=$((PASS + 1)); printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"; }
fail() { FAIL=$((FAIL + 1)); FAILED_TESTS+=("$1"); printf '  %s✗%s %s\n' "$RED" "$RESET" "$1"; }
skip() { SKIP=$((SKIP + 1)); printf '  %s○%s %s (%s)\n' "$YELLOW" "$RESET" "$1" "$2"; }

section() { printf '\n%s===%s %s\n' "$YELLOW" "$RESET" "$1"; }

cleanup_dir=""
cleanup() {
  [ -n "$cleanup_dir" ] && [ -d "$cleanup_dir" ] && rm -rf "$cleanup_dir"
}
trap cleanup EXIT

# Each test runs in a fresh tempdir so they can't interfere
fresh_workspace() {
  cleanup_dir=$(mktemp -d)
  mkdir -p "$cleanup_dir/repo"
  printf '{"type":"user","content":"hello"}\n' > "$cleanup_dir/transcript.jsonl"
  printf '{"type":"assistant","content":"hi there"}\n' >> "$cleanup_dir/transcript.jsonl"
  printf '%s' "$cleanup_dir"
}

run_hook() {
  # $1 = payload, $2 = cwd
  printf '%s' "$1" | "$HOOK" >"$2/hook.stdout" 2>"$2/hook.stderr"
  echo $?
}

#-----------------------------------------------------------------------
section "Artifact existence + permissions"
#-----------------------------------------------------------------------

[ -f "$REPO/.claude-plugin/plugin.json" ] && pass "plugin.json exists" || fail "plugin.json exists"
[ -f "$REPO/hooks/hooks.json" ] && pass "hooks/hooks.json exists" || fail "hooks/hooks.json exists"
[ -f "$REPO/skills/unclear/SKILL.md" ] && pass "SKILL.md exists" || fail "SKILL.md exists"
[ -x "$HOOK" ] && pass "snapshot.sh is executable" || fail "snapshot.sh is executable"
[ -f "$REPO/LICENSE" ] && pass "LICENSE exists" || fail "LICENSE exists"
[ -f "$REPO/README.md" ] && pass "README.md exists" || fail "README.md exists"
[ -f "$REPO/.gitignore" ] && pass ".gitignore exists" || fail ".gitignore exists"
[ -f "$REPO/demos/unclear.tape" ] && pass "demo tape exists" || fail "demo tape exists"

# Anti-mistake check from the docs: commands/skills/hooks must NOT be in .claude-plugin/
[ ! -d "$REPO/.claude-plugin/skills" ] && pass ".claude-plugin/ has no skills/ inside" || fail ".claude-plugin/ has no skills/ inside"
[ ! -d "$REPO/.claude-plugin/hooks" ] && pass ".claude-plugin/ has no hooks/ inside" || fail ".claude-plugin/ has no hooks/ inside"
[ ! -d "$REPO/.claude-plugin/commands" ] && pass ".claude-plugin/ has no commands/ inside" || fail ".claude-plugin/ has no commands/ inside"

#-----------------------------------------------------------------------
section "JSON validity"
#-----------------------------------------------------------------------

if python3 -c "import json; json.load(open('$REPO/.claude-plugin/plugin.json'))" 2>/dev/null; then
  pass "plugin.json is valid JSON"
else
  fail "plugin.json is valid JSON"
fi

if python3 -c "import json; json.load(open('$REPO/hooks/hooks.json'))" 2>/dev/null; then
  pass "hooks/hooks.json is valid JSON"
else
  fail "hooks/hooks.json is valid JSON"
fi

#-----------------------------------------------------------------------
section "plugin.json schema"
#-----------------------------------------------------------------------

python3 - <<PY
import json, sys
try:
    with open("$REPO/.claude-plugin/plugin.json") as f:
        m = json.load(f)
    assert isinstance(m.get("name"), str) and m["name"], "name missing or not a string"
    assert m["name"].islower(), "name must be lowercase"
    assert "/" not in m["name"] and " " not in m["name"], "name must not contain slashes or spaces"
    assert isinstance(m.get("description"), str), "description missing or not a string"
    assert isinstance(m.get("version"), str), "version missing or not a string"
    parts = m["version"].split(".")
    assert len(parts) == 3 and all(p.isdigit() for p in parts), "version must be semver-like X.Y.Z"
    assert isinstance(m.get("author"), dict), "author must be an object"
    assert isinstance(m["author"].get("name"), str), "author.name must be a string"
    # Forbidden fields (legacy or invented):
    for forbidden in ["skills", "commands", "hooks"]:
        assert forbidden not in m, f"plugin.json must not contain '{forbidden}' (legacy/incorrect)"
    print("OK")
except AssertionError as e:
    print(f"FAIL: {e}", file=sys.stderr)
    sys.exit(1)
PY
if [ $? -eq 0 ]; then
  pass "plugin.json matches Anthropic schema (name, description, version, author, no legacy fields)"
else
  fail "plugin.json matches Anthropic schema"
fi

#-----------------------------------------------------------------------
section "hooks.json schema"
#-----------------------------------------------------------------------

python3 - <<PY
import json, sys
try:
    with open("$REPO/hooks/hooks.json") as f:
        h = json.load(f)
    assert "hooks" in h, "top-level 'hooks' key missing"
    assert "Stop" in h["hooks"], "Stop event not registered"
    stop = h["hooks"]["Stop"]
    assert isinstance(stop, list) and stop, "Stop must be a non-empty list"
    entry = stop[0]
    assert "matcher" in entry, "matcher missing"
    assert "hooks" in entry, "inner hooks missing"
    inner = entry["hooks"][0]
    assert inner.get("type") == "command", "hook type must be 'command'"
    cmd = inner.get("command", "")
    assert "\${CLAUDE_PLUGIN_ROOT}" in cmd, "command must use \${CLAUDE_PLUGIN_ROOT}"
    assert cmd.endswith("snapshot.sh"), "command must point at snapshot.sh"
    print("OK")
except AssertionError as e:
    print(f"FAIL: {e}", file=sys.stderr)
    sys.exit(1)
PY
if [ $? -eq 0 ]; then
  pass "hooks/hooks.json matches Anthropic schema"
else
  fail "hooks/hooks.json matches Anthropic schema"
fi

#-----------------------------------------------------------------------
section "SKILL.md frontmatter"
#-----------------------------------------------------------------------

python3 - <<PY
import re, sys
try:
    with open("$REPO/skills/unclear/SKILL.md") as f:
        body = f.read()
    m = re.match(r"^---\n(.*?)\n---\n", body, re.DOTALL)
    assert m, "missing YAML frontmatter delimiters"
    fm = m.group(1)
    # name (optional per docs, but we include it)
    name_m = re.search(r"^name:\s*(\S+)", fm, re.MULTILINE)
    assert name_m and name_m.group(1) == "unclear", "name must be 'unclear'"
    # description (required)
    desc_m = re.search(r"^description:\s*(.+?)(?=\n[a-z-]+:|\Z)", fm, re.DOTALL | re.MULTILINE)
    assert desc_m, "description missing"
    desc = desc_m.group(1).strip()
    assert len(desc) > 50, "description too short to be useful"
    assert len(desc) < 1024, f"description {len(desc)} chars exceeds typical per-skill budget"
    # Body after frontmatter is non-empty
    rest = body[m.end():]
    assert len(rest.strip()) > 100, "SKILL.md body is too short"
    print(f"OK (desc={len(desc)} chars)")
except AssertionError as e:
    print(f"FAIL: {e}", file=sys.stderr)
    sys.exit(1)
PY
if [ $? -eq 0 ]; then
  pass "SKILL.md frontmatter is valid"
else
  fail "SKILL.md frontmatter is valid"
fi

#-----------------------------------------------------------------------
section "Snapshot hook — happy path"
#-----------------------------------------------------------------------

W=$(fresh_workspace)
PAYLOAD=$(printf '{"session_id":"s1","transcript_path":"%s/transcript.jsonl","cwd":"%s/repo"}' "$W" "$W")
EXIT=$(run_hook "$PAYLOAD" "$W")
[ "$EXIT" = "0" ] && pass "hook exits 0 on valid payload" || fail "hook exits 0 on valid payload (got $EXIT)"
count=$(find "$W/repo/.papercuts/snapshots" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
[ "$count" = "1" ] && pass "hook wrote exactly one snapshot" || fail "hook wrote one snapshot (got $count)"
snap=$(ls "$W/repo/.papercuts/snapshots/"*.jsonl 2>/dev/null | head -1)
if [ -f "$snap" ] && diff -q "$snap" "$W/transcript.jsonl" >/dev/null; then
  pass "snapshot contents match source transcript"
else
  fail "snapshot contents match source transcript"
fi
# Filename pattern check
fname=$(basename "$snap")
if echo "$fname" | grep -qE '^[0-9]{8}T[0-9]{6}Z\.jsonl$'; then
  pass "snapshot filename matches UTC timestamp pattern"
else
  fail "snapshot filename matches UTC timestamp pattern (got '$fname')"
fi
cleanup; cleanup_dir=""

#-----------------------------------------------------------------------
section "Snapshot hook — error handling (must never block the user)"
#-----------------------------------------------------------------------

# Empty stdin
W=$(fresh_workspace)
EXIT=$(printf '' | "$HOOK" >"$W/out" 2>"$W/err"; echo $?)
[ "$EXIT" = "0" ] && pass "exit 0 on empty stdin" || fail "exit 0 on empty stdin (got $EXIT)"
cleanup; cleanup_dir=""

# Malformed JSON
W=$(fresh_workspace)
EXIT=$(run_hook "this is not json {{{" "$W")
[ "$EXIT" = "0" ] && pass "exit 0 on malformed JSON" || fail "exit 0 on malformed JSON (got $EXIT)"
cleanup; cleanup_dir=""

# Missing transcript_path
W=$(fresh_workspace)
EXIT=$(run_hook '{"session_id":"s","cwd":"'"$W"'/repo"}' "$W")
[ "$EXIT" = "0" ] && pass "exit 0 on missing transcript_path" || fail "exit 0 on missing transcript_path (got $EXIT)"
count=$(find "$W/repo" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
[ "$count" = "0" ] && pass "no snapshot written on missing transcript_path" || fail "no snapshot written on missing transcript_path"
cleanup; cleanup_dir=""

# Missing cwd
W=$(fresh_workspace)
EXIT=$(run_hook '{"session_id":"s","transcript_path":"'"$W"'/transcript.jsonl"}' "$W")
[ "$EXIT" = "0" ] && pass "exit 0 on missing cwd" || fail "exit 0 on missing cwd (got $EXIT)"
cleanup; cleanup_dir=""

# transcript_path points at nonexistent file
W=$(fresh_workspace)
EXIT=$(run_hook '{"transcript_path":"/tmp/does-not-exist-xyz.jsonl","cwd":"'"$W"'/repo"}' "$W")
[ "$EXIT" = "0" ] && pass "exit 0 when transcript file doesn't exist" || fail "exit 0 when transcript file doesn't exist (got $EXIT)"
count=$(find "$W/repo" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
[ "$count" = "0" ] && pass "no snapshot written on missing transcript file" || fail "no snapshot on missing transcript file"
cleanup; cleanup_dir=""

# cwd doesn't exist
W=$(fresh_workspace)
EXIT=$(run_hook '{"transcript_path":"'"$W"'/transcript.jsonl","cwd":"/tmp/does-not-exist-xyz-9999"}' "$W")
[ "$EXIT" = "0" ] && pass "exit 0 when cwd doesn't exist" || fail "exit 0 when cwd doesn't exist (got $EXIT)"
cleanup; cleanup_dir=""

# Empty-string transcript_path
W=$(fresh_workspace)
EXIT=$(run_hook '{"transcript_path":"","cwd":"'"$W"'/repo"}' "$W")
[ "$EXIT" = "0" ] && pass "exit 0 on empty transcript_path" || fail "exit 0 on empty transcript_path (got $EXIT)"
cleanup; cleanup_dir=""

#-----------------------------------------------------------------------
section "Snapshot hook — retention pruning"
#-----------------------------------------------------------------------

# 7 existing → keep 5 newest
W=$(fresh_workspace)
mkdir -p "$W/repo/.papercuts/snapshots"
for i in 1 2 3 4 5 6 7; do
  fname="$W/repo/.papercuts/snapshots/2026010${i}T120000Z.jsonl"
  printf 'old\n' > "$fname"
  touch -t "2026010${i}1200" "$fname"
done
PAYLOAD=$(printf '{"transcript_path":"%s/transcript.jsonl","cwd":"%s/repo"}' "$W" "$W")
EXIT=$(run_hook "$PAYLOAD" "$W")
count=$(find "$W/repo/.papercuts/snapshots" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
[ "$count" = "5" ] && pass "retention: 7+new pruned down to 5" || fail "retention: expected 5, got $count"
# Confirm the newest (just-written) snapshot is preserved (it's the newest of all 8)
newest_file=$(ls -1t "$W/repo/.papercuts/snapshots/"*.jsonl | head -1)
if ! grep -q '^old$' "$newest_file"; then
  pass "newest snapshot is the freshly-written one (not an old seed)"
else
  fail "newest snapshot should be fresh, not from the seed batch"
fi
cleanup; cleanup_dir=""

# 0 existing → 1
W=$(fresh_workspace)
PAYLOAD=$(printf '{"transcript_path":"%s/transcript.jsonl","cwd":"%s/repo"}' "$W" "$W")
run_hook "$PAYLOAD" "$W" >/dev/null
count=$(find "$W/repo/.papercuts/snapshots" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
[ "$count" = "1" ] && pass "retention: 0 existing → 1" || fail "retention: 0 → 1 (got $count)"
cleanup; cleanup_dir=""

# Exactly 5 existing → still 5 (oldest one pruned in favor of new)
W=$(fresh_workspace)
mkdir -p "$W/repo/.papercuts/snapshots"
for i in 1 2 3 4 5; do
  fname="$W/repo/.papercuts/snapshots/2026010${i}T120000Z.jsonl"
  printf 'old\n' > "$fname"
  touch -t "2026010${i}1200" "$fname"
done
PAYLOAD=$(printf '{"transcript_path":"%s/transcript.jsonl","cwd":"%s/repo"}' "$W" "$W")
run_hook "$PAYLOAD" "$W" >/dev/null
count=$(find "$W/repo/.papercuts/snapshots" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
[ "$count" = "5" ] && pass "retention: 5+new still capped at 5" || fail "retention: 5+new (got $count)"
cleanup; cleanup_dir=""

# 100 existing → 5
W=$(fresh_workspace)
mkdir -p "$W/repo/.papercuts/snapshots"
for i in $(seq 1 100); do
  printf -v fname "%s/repo/.papercuts/snapshots/2025%05dT120000Z.jsonl" "$W" "$i"
  printf 'old\n' > "$fname"
done
PAYLOAD=$(printf '{"transcript_path":"%s/transcript.jsonl","cwd":"%s/repo"}' "$W" "$W")
run_hook "$PAYLOAD" "$W" >/dev/null
count=$(find "$W/repo/.papercuts/snapshots" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
[ "$count" = "5" ] && pass "retention: 100+new pruned to 5" || fail "retention: 100+new (got $count)"
cleanup; cleanup_dir=""

# Non-jsonl files in the snapshot dir must not be touched
W=$(fresh_workspace)
mkdir -p "$W/repo/.papercuts/snapshots"
echo "this is not a snapshot" > "$W/repo/.papercuts/snapshots/README.txt"
echo "neither is this" > "$W/repo/.papercuts/snapshots/config.json"
PAYLOAD=$(printf '{"transcript_path":"%s/transcript.jsonl","cwd":"%s/repo"}' "$W" "$W")
run_hook "$PAYLOAD" "$W" >/dev/null
[ -f "$W/repo/.papercuts/snapshots/README.txt" ] && [ -f "$W/repo/.papercuts/snapshots/config.json" ] \
  && pass "retention leaves non-jsonl files alone" \
  || fail "retention leaves non-jsonl files alone"
cleanup; cleanup_dir=""

#-----------------------------------------------------------------------
section "Snapshot hook — content fidelity"
#-----------------------------------------------------------------------

# Unicode + control characters in transcript content
W=$(fresh_workspace)
printf '{"type":"user","content":"héllo 🦀 \\u0000 \\\"quoted\\\""}\n' > "$W/transcript.jsonl"
printf '{"type":"assistant","content":"日本語テスト"}\n' >> "$W/transcript.jsonl"
PAYLOAD=$(printf '{"transcript_path":"%s/transcript.jsonl","cwd":"%s/repo"}' "$W" "$W")
run_hook "$PAYLOAD" "$W" >/dev/null
snap=$(ls "$W/repo/.papercuts/snapshots/"*.jsonl 2>/dev/null | head -1)
if [ -f "$snap" ] && diff -q "$snap" "$W/transcript.jsonl" >/dev/null; then
  pass "unicode + control chars preserved byte-for-byte"
else
  fail "unicode preservation"
fi
cleanup; cleanup_dir=""

# Spaces in cwd path
W=$(mktemp -d "/tmp/papercuts test XXXXXX")
cleanup_dir="$W"
mkdir -p "$W/repo with spaces"
printf 'test\n' > "$W/transcript.jsonl"
PAYLOAD=$(printf '{"transcript_path":"%s/transcript.jsonl","cwd":"%s/repo with spaces"}' "$W" "$W")
EXIT=$(run_hook "$PAYLOAD" "$W")
count=$(find "$W/repo with spaces" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
if [ "$EXIT" = "0" ] && [ "$count" = "1" ]; then
  pass "handles spaces in cwd path"
else
  fail "handles spaces in cwd path (exit=$EXIT, count=$count)"
fi
cleanup; cleanup_dir=""

# 1 MB transcript (boundary)
W=$(fresh_workspace)
python3 -c "
import json
with open('$W/transcript.jsonl', 'w') as f:
    for i in range(5000):
        f.write(json.dumps({'type':'user','content':'x'*200,'idx':i})+'\n')
"
size=$(wc -c < "$W/transcript.jsonl")
PAYLOAD=$(printf '{"transcript_path":"%s/transcript.jsonl","cwd":"%s/repo"}' "$W" "$W")
EXIT=$(run_hook "$PAYLOAD" "$W")
snap=$(ls "$W/repo/.papercuts/snapshots/"*.jsonl 2>/dev/null | head -1)
if [ "$EXIT" = "0" ] && [ -f "$snap" ] && [ "$(wc -c < "$snap")" = "$size" ]; then
  pass "handles ~1MB transcript ($size bytes)"
else
  fail "handles large transcript"
fi
cleanup; cleanup_dir=""

#-----------------------------------------------------------------------
section "Snapshot hook — concurrent invocations"
#-----------------------------------------------------------------------

# Two invocations in parallel — both should succeed even if filenames collide
W=$(fresh_workspace)
PAYLOAD=$(printf '{"transcript_path":"%s/transcript.jsonl","cwd":"%s/repo"}' "$W" "$W")
printf '%s' "$PAYLOAD" | "$HOOK" >/dev/null 2>&1 &
printf '%s' "$PAYLOAD" | "$HOOK" >/dev/null 2>&1 &
wait
# We don't care whether 1 or 2 snapshots exist (depends on whether they
# collided within the same second); only that neither errored out and
# at least one was written
count=$(find "$W/repo/.papercuts/snapshots" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
[ "$count" -ge "1" ] && pass "concurrent invocations don't crash (wrote $count file(s))" || fail "concurrent invocations (got $count)"
cleanup; cleanup_dir=""

#-----------------------------------------------------------------------
section "done-prover — artifact existence"
#-----------------------------------------------------------------------

[ -f "$REPO/skills/done-prover/SKILL.md" ] && pass "done-prover SKILL.md exists" || fail "done-prover SKILL.md exists"
[ -f "$REPO/skills/done-prover/README.md" ] && pass "done-prover README.md exists" || fail "done-prover README.md exists"
[ -x "$DONE_HOOK" ] && pass "verify-claims.sh is executable" || fail "verify-claims.sh is executable"
[ -f "$REPO/demos/done-prover.gif" ] && pass "done-prover demo GIF exists" || fail "done-prover demo GIF exists"
[ -f "$REPO/demos/done-prover.tape" ] && pass "done-prover tape exists" || fail "done-prover tape exists"
[ -x "$REPO/demos/scenario-done-prover.sh" ] && pass "done-prover scenario script is executable" || fail "done-prover scenario script is executable"

#-----------------------------------------------------------------------
section "done-prover — SKILL.md frontmatter"
#-----------------------------------------------------------------------

python3 - <<PY
import re, sys
try:
    with open("$REPO/skills/done-prover/SKILL.md") as f:
        body = f.read()
    m = re.match(r"^---\n(.*?)\n---\n", body, re.DOTALL)
    assert m, "missing YAML frontmatter delimiters"
    fm = m.group(1)
    name_m = re.search(r"^name:\s*(\S+)", fm, re.MULTILINE)
    assert name_m and name_m.group(1) == "done-prover", "name must be 'done-prover'"
    desc_m = re.search(r"^description:\s*(.+?)(?=\n[a-z-]+:|\Z)", fm, re.DOTALL | re.MULTILINE)
    assert desc_m, "description missing"
    desc = desc_m.group(1).strip()
    assert 50 < len(desc) < 1024, f"description {len(desc)} chars out of useful range"
    rest = body[m.end():]
    assert len(rest.strip()) > 100, "SKILL.md body is too short"
    print(f"OK (desc={len(desc)} chars)")
except AssertionError as e:
    print(f"FAIL: {e}", file=sys.stderr)
    sys.exit(1)
PY
if [ $? -eq 0 ]; then
  pass "done-prover SKILL.md frontmatter is valid"
else
  fail "done-prover SKILL.md frontmatter"
fi

#-----------------------------------------------------------------------
section "done-prover — hook fail-safe behavior"
#-----------------------------------------------------------------------

# Empty stdin must not crash the hook
EXIT=$(printf '' | "$DONE_HOOK" >/dev/null 2>&1; echo $?)
[ "$EXIT" = "0" ] && pass "exit 0 on empty stdin" || fail "exit 0 on empty stdin (got $EXIT)"

# Malformed JSON must not crash
EXIT=$(printf 'not json {{{' | "$DONE_HOOK" >/dev/null 2>&1; echo $?)
[ "$EXIT" = "0" ] && pass "exit 0 on malformed JSON" || fail "exit 0 on malformed JSON (got $EXIT)"

# Missing transcript_path must not crash
EXIT=$(printf '{"cwd":"/tmp"}' | "$DONE_HOOK" >/dev/null 2>&1; echo $?)
[ "$EXIT" = "0" ] && pass "exit 0 on missing transcript_path" || fail "exit 0 on missing transcript_path"

# Nonexistent transcript path must not crash
EXIT=$(printf '{"transcript_path":"/does/not/exist","cwd":"/tmp"}' | "$DONE_HOOK" >/dev/null 2>&1; echo $?)
[ "$EXIT" = "0" ] && pass "exit 0 on missing transcript file" || fail "exit 0 on missing transcript file"

#-----------------------------------------------------------------------
section "done-prover — claim detection and verdict"
#-----------------------------------------------------------------------

# Case A: no claim → silent
W=$(mktemp -d)
cat > "$W/t.jsonl" <<'EOF'
{"type":"user","message":{"role":"user","content":"hi"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"I'll help with that."}]}}
EOF
PAYLOAD=$(printf '{"transcript_path":"%s/t.jsonl","cwd":"%s"}' "$W" "$W")
OUT=$(echo "$PAYLOAD" | "$DONE_HOOK")
[ -z "$OUT" ] && pass "no claim → silent (no block)" || fail "no claim → silent (got: $OUT)"
rm -rf "$W"

# Case B: claim but tests passed → silent (claim is honest)
W=$(mktemp -d)
cat > "$W/t.jsonl" <<'EOF'
{"type":"user","message":{"role":"user","content":"run tests"}}
{"type":"tool_result","content":"============ 47 passed in 1.2s ============"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"All 47 tests pass."}]}}
EOF
PAYLOAD=$(printf '{"transcript_path":"%s/t.jsonl","cwd":"%s"}' "$W" "$W")
OUT=$(echo "$PAYLOAD" | "$DONE_HOOK")
[ -z "$OUT" ] && pass "honest claim → silent" || fail "honest claim → silent (got: $OUT)"
rm -rf "$W"

# Case C: claim WITH failures → block JSON output
W=$(mktemp -d)
cat > "$W/t.jsonl" <<'EOF'
{"type":"user","message":{"role":"user","content":"run tests"}}
{"type":"tool_result","content":"FAILED tests/test_auth.py::test_token\n45 passed, 2 failed, 1 skipped in 1.5s"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"All 47 tests pass."}]}}
EOF
PAYLOAD=$(printf '{"transcript_path":"%s/t.jsonl","cwd":"%s"}' "$W" "$W")
OUT=$(echo "$PAYLOAD" | "$DONE_HOOK")
# Must be valid JSON with decision=block
DECISION=$(echo "$OUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('decision',''))" 2>/dev/null)
[ "$DECISION" = "block" ] && pass "false claim → JSON decision=block" || fail "false claim → block (got: $OUT)"
# Verdict markdown artifact must have been written
ls "$W/.papercuts/proofs/"*.md >/dev/null 2>&1 && pass "verdict artifact written to .papercuts/proofs/" || fail "verdict artifact written"
rm -rf "$W"

# Case D: "X tests pass" numeric claim with actual failures → blocked
W=$(mktemp -d)
cat > "$W/t.jsonl" <<'EOF'
{"type":"user","message":{"role":"user","content":"check"}}
{"type":"tool_result","content":"3 failed, 12 passed in 0.4s"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"15 tests pass — feature complete."}]}}
EOF
PAYLOAD=$(printf '{"transcript_path":"%s/t.jsonl","cwd":"%s"}' "$W" "$W")
OUT=$(echo "$PAYLOAD" | "$DONE_HOOK")
DECISION=$(echo "$OUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('decision',''))" 2>/dev/null)
[ "$DECISION" = "block" ] && pass "numeric claim with failures → block" || fail "numeric claim → block"
rm -rf "$W"

# Case E: "all green" with AssertionError → blocked
W=$(mktemp -d)
cat > "$W/t.jsonl" <<'EOF'
{"type":"user","message":{"role":"user","content":"again"}}
{"type":"tool_result","content":"raise AssertionError('oops')\n\nE   AssertionError: oops"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Everything is green now."}]}}
EOF
PAYLOAD=$(printf '{"transcript_path":"%s/t.jsonl","cwd":"%s"}' "$W" "$W")
OUT=$(echo "$PAYLOAD" | "$DONE_HOOK")
DECISION=$(echo "$OUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('decision',''))" 2>/dev/null)
[ "$DECISION" = "block" ] && pass "AssertionError surfaced under 'all green' claim" || fail "AssertionError → block"
rm -rf "$W"

# Case F: claim without ANY tool_result history → silent (no evidence to verify against)
W=$(mktemp -d)
cat > "$W/t.jsonl" <<'EOF'
{"type":"user","message":{"role":"user","content":"hi"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"All tests pass."}]}}
EOF
PAYLOAD=$(printf '{"transcript_path":"%s/t.jsonl","cwd":"%s"}' "$W" "$W")
OUT=$(echo "$PAYLOAD" | "$DONE_HOOK")
[ -z "$OUT" ] && pass "claim without evidence → silent (no false positives)" || fail "claim w/o evidence → silent (got: $OUT)"
rm -rf "$W"

#-----------------------------------------------------------------------
section "hooks.json — both Stop hooks registered"
#-----------------------------------------------------------------------

python3 - <<PY
import json, sys
try:
    with open("$REPO/hooks/hooks.json") as f:
        h = json.load(f)
    stop = h["hooks"]["Stop"]
    inner_hooks = stop[0]["hooks"]
    cmds = [hk["command"] for hk in inner_hooks]
    assert any("snapshot.sh" in c for c in cmds), "snapshot.sh not registered"
    assert any("verify-claims.sh" in c for c in cmds), "verify-claims.sh not registered"
    assert all("\${CLAUDE_PLUGIN_ROOT}" in c for c in cmds), "all hooks must use \${CLAUDE_PLUGIN_ROOT}"
    print("OK")
except (AssertionError, KeyError, IndexError) as e:
    print(f"FAIL: {e}", file=sys.stderr)
    sys.exit(1)
PY
if [ $? -eq 0 ]; then
  pass "hooks.json registers both Stop hooks with CLAUDE_PLUGIN_ROOT"
else
  fail "hooks.json registration"
fi

#-----------------------------------------------------------------------
section "skill-budget — artifact existence"
#-----------------------------------------------------------------------

[ -f "$REPO/skills/skill-budget/SKILL.md" ] && pass "skill-budget SKILL.md exists" || fail "skill-budget SKILL.md exists"
[ -f "$REPO/skills/skill-budget/README.md" ] && pass "skill-budget README.md exists" || fail "skill-budget README.md exists"
[ -x "$AUDIT" ] && pass "audit.py is executable" || fail "audit.py is executable"
[ -f "$REPO/demos/skill-budget.gif" ] && pass "skill-budget demo GIF exists" || fail "skill-budget demo GIF exists"
[ -f "$REPO/demos/skill-budget.tape" ] && pass "skill-budget tape exists" || fail "skill-budget tape exists"
[ -x "$REPO/demos/scenario-skill-budget.sh" ] && pass "skill-budget scenario script is executable" || fail "skill-budget scenario script is executable"

#-----------------------------------------------------------------------
section "skill-budget — SKILL.md frontmatter"
#-----------------------------------------------------------------------

python3 - <<PY
import re, sys
try:
    with open("$REPO/skills/skill-budget/SKILL.md") as f:
        body = f.read()
    m = re.match(r"^---\n(.*?)\n---\n", body, re.DOTALL)
    assert m, "missing YAML frontmatter delimiters"
    fm = m.group(1)
    name_m = re.search(r"^name:\s*(\S+)", fm, re.MULTILINE)
    assert name_m and name_m.group(1) == "skill-budget", "name must be 'skill-budget'"
    desc_m = re.search(r"^description:\s*(.+?)(?=\n[a-z-]+:|\Z)", fm, re.DOTALL | re.MULTILINE)
    assert desc_m, "description missing"
    desc = desc_m.group(1).strip()
    assert 50 < len(desc) < 1024, f"description {len(desc)} chars out of useful range"
    print(f"OK (desc={len(desc)} chars)")
except AssertionError as e:
    print(f"FAIL: {e}", file=sys.stderr)
    sys.exit(1)
PY
if [ $? -eq 0 ]; then
  pass "skill-budget SKILL.md frontmatter is valid"
else
  fail "skill-budget SKILL.md frontmatter"
fi

#-----------------------------------------------------------------------
section "skill-budget — audit.py behavior"
#-----------------------------------------------------------------------

# Helper: seed a sandbox with N skills at given char costs
seed_sandbox() {
  local box="$1"; shift
  mkdir -p "$box/.claude/skills"
  for spec in "$@"; do
    local name="${spec%%:*}"; local desc="${spec#*:}"
    mkdir -p "$box/.claude/skills/$name"
    printf -- "---\nname: %s\ndescription: %s\n---\n" "$name" "$desc" > "$box/.claude/skills/$name/SKILL.md"
  done
}

# Case A: empty sandbox → exit 0, no skills reported
W=$(mktemp -d); mkdir -p "$W/.claude/skills"
cd "$W"; OUT=$("$AUDIT" --no-color 2>&1); EXIT=$?
cd /tmp
[ "$EXIT" = "0" ] && pass "audit.py exits 0 on empty sandbox" || fail "audit.py empty sandbox exit (got $EXIT)"
echo "$OUT" | grep -q "No skills found" && pass "audit.py reports 'No skills found' on empty" || fail "audit.py empty message"
rm -rf "$W"

# Case B: single skill under budget → all visible
W=$(mktemp -d)
seed_sandbox "$W" "tiny:a short description for testing"
cd "$W"; OUT=$("$AUDIT" --budget 15000 --no-color 2>&1); EXIT=$?
cd /tmp
[ "$EXIT" = "0" ] && pass "audit.py exits 0 with 1 skill" || fail "audit.py 1-skill exit"
echo "$OUT" | grep -q "✓ visible" && pass "single small skill shows as visible" || fail "small skill visibility"
rm -rf "$W"

# Case C: many skills with tight budget → some marked INVISIBLE
W=$(mktemp -d)
seed_sandbox "$W" \
  "a:$(printf 'x%.0s' {1..300})" \
  "b:$(printf 'y%.0s' {1..300})" \
  "c:$(printf 'z%.0s' {1..300})" \
  "d:$(printf 'q%.0s' {1..300})"
cd "$W"; OUT=$("$AUDIT" --budget 700 --no-color 2>&1); EXIT=$?
cd /tmp
[ "$EXIT" = "0" ] && pass "audit.py exits 0 with budget overflow" || fail "audit.py overflow exit"
echo "$OUT" | grep -q "INVISIBLE" && pass "INVISIBLE marker shown when over budget" || fail "INVISIBLE marker"
echo "$OUT" | grep -q "Suggested actions" && pass "Suggested actions section shown" || fail "suggested actions"
rm -rf "$W"

# Case D: malformed SKILL.md → does not crash
W=$(mktemp -d)
mkdir -p "$W/.claude/skills/broken"
echo "garbage content no frontmatter" > "$W/.claude/skills/broken/SKILL.md"
mkdir -p "$W/.claude/skills/empty"
: > "$W/.claude/skills/empty/SKILL.md"
cd "$W"; OUT=$("$AUDIT" --no-color 2>&1); EXIT=$?
cd /tmp
[ "$EXIT" = "0" ] && pass "audit.py exits 0 with malformed SKILL.md files" || fail "audit.py malformed exit"
echo "$OUT" | grep -q "broken" && pass "audit.py falls back to folder name for missing frontmatter" || fail "audit.py folder-name fallback"
rm -rf "$W"

# Case E: --json produces valid machine-readable output
W=$(mktemp -d)
seed_sandbox "$W" "alpha:short desc" "beta:another short"
cd "$W"; OUT=$("$AUDIT" --json 2>&1); EXIT=$?
cd /tmp
[ "$EXIT" = "0" ] && pass "audit.py --json exits 0" || fail "audit.py --json exit"
echo "$OUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['skill_count'] == 2, f'expected 2 skills, got {d[\"skill_count\"]}'
assert d['total_chars'] > 0, 'expected non-zero total'
assert all('status' in s for s in d['skills']), 'each skill must have status field'
print('OK')
" 2>/dev/null && pass "audit.py --json schema is correct" || fail "audit.py --json schema"
rm -rf "$W"

# Case F: --budget flag actually changes output
W=$(mktemp -d)
seed_sandbox "$W" "z:$(printf 'x%.0s' {1..500})"
cd "$W"
OUT_HIGH=$("$AUDIT" --budget 15000 --no-color 2>&1)
OUT_LOW=$("$AUDIT" --budget 100 --no-color 2>&1)
cd /tmp
echo "$OUT_HIGH" | grep -q "✓ visible" && \
  echo "$OUT_LOW"  | grep -q "INVISIBLE" && \
  pass "--budget flag changes visibility classification" || \
  fail "--budget flag effect"
rm -rf "$W"

#-----------------------------------------------------------------------
section "Static analysis — shellcheck"
#-----------------------------------------------------------------------

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$HOOK"; then
    pass "shellcheck passes on snapshot.sh"
  else
    fail "shellcheck passes on snapshot.sh"
  fi
  if shellcheck "$DONE_HOOK"; then
    pass "shellcheck passes on verify-claims.sh"
  else
    fail "shellcheck passes on verify-claims.sh"
  fi
else
  skip "shellcheck on snapshot.sh" "shellcheck not installed"
  skip "shellcheck on verify-claims.sh" "shellcheck not installed"
fi

# Run the test runner through shellcheck too (skip SC2086 cases we already know about)
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck --severity=error "$SCRIPT_DIR/run-all.sh"; then
    pass "shellcheck (errors only) passes on run-all.sh itself"
  else
    fail "shellcheck on run-all.sh"
  fi
fi

#-----------------------------------------------------------------------
section "README + docs sanity"
#-----------------------------------------------------------------------

# README references the actual repo URL
if grep -q "github.com/dhruba-datta/claude-papercuts" "$REPO/README.md"; then
  pass "README references the correct GitHub URL"
else
  fail "README has the wrong/missing GitHub URL"
fi

# No leftover [handle] placeholders (exclude tests/ which grep-references the pattern itself, and .git/)
if ! grep -rn --exclude-dir=tests --exclude-dir=.git "\[handle\]" "$REPO" 2>/dev/null; then
  pass "no leftover [handle] placeholders in repo"
else
  fail "leftover [handle] placeholders found"
fi

# docs/issues.md has all 16 issues referenced
issue_refs=$(grep -oE "#[0-9]+" "$REPO/docs/issues.md" | sort -u | wc -l | tr -d ' ')
[ "$issue_refs" -ge "16" ] && pass "docs/issues.md references at least 16 issue numbers" || fail "docs/issues.md only references $issue_refs unique issue numbers (need 16)"

# README has the 10-skill table
table_rows=$(grep -cE "^\| [0-9]+ \|" "$REPO/README.md")
[ "$table_rows" = "10" ] && pass "README skill table has exactly 10 rows" || fail "README skill table has $table_rows rows (need 10)"

#-----------------------------------------------------------------------
section "Summary"
#-----------------------------------------------------------------------

TOTAL=$((PASS + FAIL))
printf '\n  %sPassed%s: %d / %d\n' "$GREEN" "$RESET" "$PASS" "$TOTAL"
if [ "$SKIP" -gt 0 ]; then
  printf '  %sSkipped%s: %d\n' "$YELLOW" "$RESET" "$SKIP"
fi
if [ "$FAIL" -gt 0 ]; then
  printf '  %sFailed%s: %d\n' "$RED" "$RESET" "$FAIL"
  printf '\nFailed tests:\n'
  for t in "${FAILED_TESTS[@]}"; do
    printf '  - %s\n' "$t"
  done
  exit 1
fi

printf '\n  %sAll tests passed.%s\n' "$GREEN" "$RESET"
exit 0
