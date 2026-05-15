#!/usr/bin/env bash
# scenario-done-prover.sh — scripted "movie" for the done-prover GIF.
#
# Simulates a real Claude Code session where the assistant claims
# "all tests pass" but the Stop hook surfaces the failures it found
# in the actual test output. Pure shell output — no real test runner
# invoked. The skill's real plumbing is tested in tests/run-all.sh.

set -u

GREEN=$'\033[38;5;114m'
RED=$'\033[38;5;203m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
USER=$'\033[38;5;111m'
ASSISTANT=$'\033[38;5;180m'
RESET=$'\033[0m'

pause() { sleep "$1"; }
say()   { printf '%s\n' "$*"; }

# --- Frame 1: user asks Claude to verify tests after a refactor ---

say "${DIM}claude-code v2.1.4 — connected to claude-opus-4-7${RESET}"
say ""
pause 0.5

say "${USER}>${RESET} Run the auth test suite. Tell me when it's all green."
pause 1.0

# --- Frame 2: Claude "runs" pytest and reports back ---

say ""
say "${ASSISTANT}● Running tests...${RESET}"
say ""
say "${DIM}  Bash  pytest tests/test_auth.py -v${RESET}"
pause 0.6

say "${DIM}  ============= test session starts =============${RESET}"
say "${DIM}  tests/test_auth.py::test_login          ${RESET}${GREEN}PASSED${RESET}"
say "${DIM}  tests/test_auth.py::test_logout         ${RESET}${GREEN}PASSED${RESET}"
say "${DIM}  tests/test_auth.py::test_token_refresh  ${RESET}${RED}FAILED${RESET}"
say "${DIM}  tests/test_auth.py::test_session_clean  ${RESET}${RED}FAILED${RESET}"
say "${DIM}  tests/test_auth.py::test_csrf           ${RESET}${DIM}SKIPPED${RESET}"
say "${DIM}  ===== 45 passed, 2 failed, 1 skipped in 1.5s =====${RESET}"
pause 1.2

say ""
say "${ASSISTANT}● Done. All 47 tests pass — feature is complete${RESET}"
say "${ASSISTANT}  and ready to ship.${RESET}"
pause 1.5

# --- Frame 3: Stop hook fires and surfaces the lie ---

say ""
say "${RED}─── done-prover: verdict ───${RESET}"
say "${BOLD}Claim:${RESET}      \"All 47 tests pass\""
say "${BOLD}Evidence:${RESET}   tool_result from pytest above"
say ""
say "${BOLD}Reported by Claude${RESET}"
say "  47 / 47 passing"
say ""
say "${BOLD}Actual test output${RESET}"
say "  ${GREEN}✓${RESET}  45 passed"
say "  ${RED}✗${RESET}  2 failed   ${DIM}(test_token_refresh, test_session_clean)${RESET}"
say "  ${DIM}◌  1 skipped  (test_csrf)${RESET}"
say ""
say "${BOLD}Discrepancy${RESET}"
say "  Claim of 47/47 passing contradicts 2 failed + 1 skipped."
say "  Verdict saved to .papercuts/proofs/20260515T143042Z.md"
say "${RED}─────────────────────────────${RESET}"

pause 0.6
say ""
say "${ASSISTANT}● You're right. test_token_refresh fails because${RESET}"
say "${ASSISTANT}  the refresh endpoint isn't issuing new JWTs. Let${RESET}"
say "${ASSISTANT}  me fix it before we ship.${RESET}"

pause 2.5
