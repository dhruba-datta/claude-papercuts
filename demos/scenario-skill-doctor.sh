#!/usr/bin/env bash
# scenario-skill-doctor.sh — scripted "movie" for the skill-doctor GIF.

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

say "${DIM}claude-code v2.1.4 — connected to claude-opus-4-7${RESET}"
say ""
pause 0.3

say "${USER}>${RESET} I wrote a new skill and it's not triggering. Why?"
pause 0.7

say ""
say "${USER}>${RESET} /claude-papercuts:skill-doctor ./my-skill/SKILL.md"
pause 0.8

say ""
say "${ACCENT}● Linting SKILL.md...${RESET}"
say "${DIM}  Bash  ~/.claude/plugins/claude-papercuts/skills/skill-doctor/lint.py ./my-skill/SKILL.md${RESET}"
pause 0.8

say ""
say "${BOLD}skill-doctor — lint 1 SKILL.md file(s)${RESET}"
say "${DIM}────────────────────────────────────────────────────────────${RESET}"
say ""
say "${BOLD}git-helper${RESET}  ${DIM}./my-skill/SKILL.md${RESET}"
pause 0.6
say "  ${AMBER}⚠ WARN${RESET}   ${DIM}desc-thin${RESET}        description is only 67 chars — add a trigger phrase and an example"
pause 0.4
say "  ${AMBER}⚠ WARN${RESET}   ${DIM}no-trigger${RESET}       no 'Use this when …' phrase — model has nothing to route on"
pause 0.4
say "  ${AMBER}⚠ WARN${RESET}   ${DIM}training-overlap${RESET} vague 'git operations' — name the specific git workflow this skill owns"
pause 0.4
say "  ${AMBER}⚠ WARN${RESET}   ${DIM}training-overlap${RESET} 'reading files' overlaps with the built-in Read tool"
pause 0.4
say "  ${DIM}· INFO   vague-helper      a 'helper' that doesn't say what it helps with${RESET}"
say ""
say "${DIM}────────────────────────────────────────────────────────────${RESET}"
say "${AMBER}1 skill(s) lint clean${RESET}  ${DIM}(4 warnings to consider)${RESET}"
pause 1.5

say ""
say "${USER}>${RESET} what should I change?"
pause 0.6

say ""
say "${ACCENT}● Three concrete fixes:${RESET}"
say "${ACCENT}  1. Replace 'git operations' with the specific workflow this${RESET}"
say "${ACCENT}     skill owns — e.g. 'apply a stacked-diff rebase' instead${RESET}"
say "${ACCENT}     of a generic git description. Built-in Bash wins at that${RESET}"
say "${ACCENT}     level of vagueness.${RESET}"
say "${ACCENT}  2. Drop 'helper' — replace with what it actually does.${RESET}"
say "${ACCENT}  3. Add 'Use this skill when …' — the canonical trigger${RESET}"
say "${ACCENT}     phrase Anthropic's templates rely on for routing.${RESET}"
pause 3.0
