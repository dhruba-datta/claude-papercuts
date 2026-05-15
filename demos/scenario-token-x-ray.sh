#!/usr/bin/env bash
# scenario-token-x-ray.sh — scripted "movie" for the token-x-ray GIF.
#
# Prints a deterministic, realistic version of the audit output. The
# real audit script (skills/token-x-ray/audit.py) is tested in
# tests/run-all.sh.

set -u

GREEN=$'\033[38;5;114m'
RED=$'\033[38;5;203m'
AMBER=$'\033[38;5;179m'
CYAN=$'\033[38;5;111m'
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
pause 0.4

say "${USER}>${RESET} /context"
pause 0.4
say ""
say "${DIM}Auto-injected: 18,420 tokens (9.2% of window)${RESET}"
say "${DIM}  System prompt:    3,200${RESET}"
say "${DIM}  MCP servers:     12,000${RESET}"
say "${DIM}  Skills:           1,580${RESET}"
say "${DIM}  CLAUDE.md:        1,240${RESET}"
say "${DIM}  Subagents:          400${RESET}"
say ""
pause 1.0
say "${USER}>${RESET} which skills? which CLAUDE.md? /context won't tell me."
pause 0.8
say ""
say "${USER}>${RESET} /claude-papercuts:token-x-ray"
pause 0.8

say ""
say "${ACCENT}● Running token-x-ray audit...${RESET}"
say "${DIM}  Bash  ~/.claude/plugins/claude-papercuts/skills/token-x-ray/audit.py${RESET}"
pause 1.0

# --- Frame 2: the audit output ---

say ""
say "${BOLD}token-x-ray — auto-injected context audit${RESET}"
say "${DIM}────────────────────────────────────────────────────────────${RESET}"
say "Project: /Users/you/code/my-app"
say "Home:    /Users/you"
say ""
say "${BOLD}Total estimated: 15,220 tokens${RESET}  ${DIM}(@ 4 chars/token)${RESET}"
say ""
pause 0.5

say "${BOLD}By category:${RESET}"
say "  MCP servers       ${RED}████████████████████████${RESET}  12,000 tok  ${DIM}(8 items)${RESET}"
say "  Skills            ${AMBER}███░░░░░░░░░░░░░░░░░░░░░${RESET}   1,580 tok  ${DIM}(22 items)${RESET}"
say "  CLAUDE.md         ${AMBER}██░░░░░░░░░░░░░░░░░░░░░░${RESET}   1,240 tok  ${DIM}(2 items)${RESET}"
say "  Subagents         ${CYAN}█░░░░░░░░░░░░░░░░░░░░░░░${RESET}     400 tok  ${DIM}(4 items)${RESET}"
say ""
pause 0.6

say "${BOLD}Top sources (by tokens):${RESET}"
say "  github                          MCP servers     user     ${RED}██████████████████${RESET}  1,500 tok  ${DIM}~1500 tok (schema not measured)${RESET}"
say "  filesystem                      MCP servers     user     ${RED}██████████████████${RESET}  1,500 tok  ${DIM}~1500 tok (schema not measured)${RESET}"
say "  postgres                        MCP servers     user     ${RED}██████████████████${RESET}  1,500 tok  ${DIM}~1500 tok (schema not measured)${RESET}"
say "  slack                           MCP servers     user     ${RED}██████████████████${RESET}  1,500 tok  ${DIM}~1500 tok (schema not measured)${RESET}"
say "  notion                          MCP servers     user     ${RED}██████████████████${RESET}  1,500 tok  ${DIM}~1500 tok (schema not measured)${RESET}"
say "  ${DIM}... 3 more MCP servers ...${RESET}"
say "  project/CLAUDE.md               CLAUDE.md       project  ${AMBER}██████████░░░░░░░░${RESET}    830 tok"
say "  doc-writer                      Skills          user     ${CYAN}███░░░░░░░░░░░░░░░${RESET}    310 tok"
say "  CLAUDE.md                       CLAUDE.md       user     ${CYAN}████░░░░░░░░░░░░░░${RESET}    410 tok"
say "  researcher                      Subagents       user     ${CYAN}██░░░░░░░░░░░░░░░░${RESET}    200 tok"
say ""
pause 0.6

say "${BOLD}Top cuts (potential savings: ~4,500 tokens):${RESET}"
say "  ${AMBER}→${RESET} github      ${DIM}(1,500 tok, mcp)${RESET}"
say "      ${DIM}remove 'github' from .claude.json${RESET}"
say "  ${AMBER}→${RESET} filesystem  ${DIM}(1,500 tok, mcp)${RESET}"
say "      ${DIM}remove 'filesystem' from .claude.json${RESET}"
say "  ${AMBER}→${RESET} postgres    ${DIM}(1,500 tok, mcp)${RESET}"
say "      ${DIM}remove 'postgres' from .claude.json${RESET}"
say ""
pause 0.4

say "${AMBER}⚠ 8 MCP server(s) declared. Token cost is a heuristic (1500 tok each).${RESET}"
say "${DIM}  Run /context inside Claude Code for the authoritative number.${RESET}"

pause 3.0
