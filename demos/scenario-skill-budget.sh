#!/usr/bin/env bash
# scenario-skill-budget.sh — scripted "movie" for the skill-budget GIF.
#
# Prints a deterministic, realistic version of the audit output. The
# real audit script (skills/skill-budget/audit.py) is tested in
# tests/run-all.sh.

set -u

GREEN=$'\033[38;5;114m'
RED=$'\033[38;5;203m'
AMBER=$'\033[38;5;179m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
USER=$'\033[38;5;111m'
ACCENT=$'\033[38;5;180m'
RESET=$'\033[0m'

pause() { sleep "$1"; }
say()   { printf '%s\n' "$*"; }

# --- Frame 1: user invokes the slash command ---

say "${DIM}claude-code v2.1.4 — connected to claude-opus-4-7${RESET}"
say ""
pause 0.5

say "${USER}>${RESET} /claude-papercuts:skill-budget"
pause 0.8

say ""
say "${ACCENT}● Running skill-budget audit...${RESET}"
say "${DIM}  Bash  ~/.claude/plugins/claude-papercuts/skills/skill-budget/audit.py${RESET}"
pause 1.0

# --- Frame 2: the audit output ---

say ""
say "${BOLD}Skill budget audit${RESET}"
say "${DIM}────────────────────────────────────────────────────────────${RESET}"
say "Budget:  15,000 chars (override with --budget)"
say "Usage:   ${AMBER}13,420 chars  (89.5%)${RESET}"
say ""
say "  ${AMBER}████████████████████████████████████████████${RESET}${DIM}░░░░░░${RESET}  13,420 / 15,000"
say ""
pause 0.6

say "32 skills across 3 source(s):"
say "  user      14 skill(s)"
say "  project    6 skill(s)"
say "  plugin    12 skill(s)"
say ""
pause 0.4

say "${BOLD}By char weight:${RESET}"
say "  doc-writer                ██████████████████   1,240 ch  ${GREEN}✓ visible${RESET}"
say "  pdf-extractor             ████████████░          987 ch  ${GREEN}✓ visible${RESET}"
say "  schema-migrator           ████████████          892 ch  ${GREEN}✓ visible${RESET}"
say "  test-runner               ███████████           834 ch  ${GREEN}✓ visible${RESET}"
say "  deploy-orchestrator       ██████████░           756 ch  ${GREEN}✓ visible${RESET}"
say "  ${DIM}... 17 more ...${RESET}"
say "  legacy-git-helper         ████░                 312 ch  ${AMBER}⚠ at risk${RESET}"
say "  old-pdf-parser            ███░                  287 ch  ${RED}✗ INVISIBLE${RESET}"
say "  marketing-assistant       ██░                   245 ch  ${RED}✗ INVISIBLE${RESET}"
say "  data-cleanup-v1           ██░                   220 ch  ${RED}✗ INVISIBLE${RESET}"
say "  scratch-skill             █                     150 ch  ${RED}✗ INVISIBLE${RESET}"
say ""
pause 0.5

say "${RED}4 skill(s) are INVISIBLE TO CLAUDE right now:${RESET}"
say "${RED}  ✗ old-pdf-parser${RESET}        ${DIM}(~/.claude/plugins/document/skills/old-pdf-parser/SKILL.md)${RESET}"
say "${RED}  ✗ marketing-assistant${RESET}   ${DIM}(~/.claude/skills/marketing-assistant/SKILL.md)${RESET}"
say "${RED}  ✗ data-cleanup-v1${RESET}       ${DIM}(~/.claude/skills/data-cleanup-v1/SKILL.md)${RESET}"
say "${RED}  ✗ scratch-skill${RESET}         ${DIM}(.claude/skills/scratch-skill/SKILL.md)${RESET}"
say ""
pause 0.4

say "${BOLD}Suggested actions:${RESET}"
say "${DIM}  Disable a skill by renaming its SKILL.md:${RESET}"
say "${DIM}    mv ~/.claude/skills/marketing-assistant/SKILL.md \\${RESET}"
say "${DIM}       ~/.claude/skills/marketing-assistant/SKILL.md.disabled${RESET}"
say "${DIM}    ...and 3 more${RESET}"

pause 2.8
