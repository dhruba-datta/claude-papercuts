#!/usr/bin/env python3
"""
audit.py — discover every source of auto-injected context Claude Code
loads at session start, estimate its token cost, and suggest the biggest
cuts.

Issue anthropics/claude-code#39686 documents the visibility gap: 43
cloud skills + 26 plugins silently injected ~6,000 tokens with no
breakdown and no opt-out. `/context` shows category totals; this script
breaks each category down to individual files so you know exactly what
to disable.

Token estimate is the standard 4-chars-per-token heuristic. Real
tokenization varies by content — treat numbers as ±20%.

Sources audited:
  - MCP servers           ~/.claude.json, .claude/settings*.json
  - CLAUDE.md files       ~/.claude/CLAUDE.md, <cwd>/CLAUDE.md
  - Skills                ~/.claude/skills, .claude/skills,
                          ~/.claude/plugins/*/skills
  - Subagents             ~/.claude/agents, .claude/agents
  - Slash commands        ~/.claude/commands, .claude/commands

Usage:
    audit.py [--json] [--no-color] [--cwd PATH] [--home PATH]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, asdict, field
from pathlib import Path
from typing import Iterable

CHARS_PER_TOKEN = 4
MCP_TOOLS_HEURISTIC_TOKENS = 1500  # per declared MCP server, rough avg


class Color:
    def __init__(self, enabled: bool):
        self.enabled = enabled

    def _wrap(self, code: str, s: str) -> str:
        return f"\033[{code}m{s}\033[0m" if self.enabled else s

    def green(self, s):  return self._wrap("38;5;114", s)
    def amber(self, s):  return self._wrap("38;5;179", s)
    def red(self, s):    return self._wrap("38;5;203", s)
    def cyan(self, s):   return self._wrap("38;5;111", s)
    def dim(self, s):    return self._wrap("2",        s)
    def bold(self, s):   return self._wrap("1",        s)


@dataclass
class Source:
    category: str       # mcp | claude_md | skill | agent | command
    name: str
    scope: str          # user | project | plugin | unknown
    path: str           # absolute path or "(config)"
    chars: int          # measured chars (0 when unmeasured)
    tokens: int         # estimated tokens
    note: str = ""      # e.g. "schema not measured"


# ---------- generic helpers ----------

def read_text_safe(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""


def parse_frontmatter(text: str) -> tuple[str, str]:
    """Return (name, description) from a leading YAML frontmatter block."""
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return "", ""
    fm = m.group(1)
    name = ""
    description = ""
    nm = re.search(r"^name:\s*(.+?)\s*$", fm, re.MULTILINE)
    if nm:
        name = nm.group(1).strip().strip('"').strip("'")
    dm = re.search(r"^description:\s*(.+?)(?=\n[a-z][a-z0-9_-]*:|\Z)",
                   fm, re.DOTALL | re.MULTILINE | re.IGNORECASE)
    if dm:
        description = re.sub(r"\s+", " ", dm.group(1).strip().strip('"').strip("'"))
    return name, description


def tokens_for(chars: int) -> int:
    return max(1, chars // CHARS_PER_TOKEN) if chars else 0


# ---------- MCP discovery ----------

def discover_mcp(home: Path, cwd: Path) -> list[Source]:
    """Look in the standard settings files for `mcpServers` and yield one
    Source per declared server. Token cost is unmeasurable from disk
    (would require invoking the server), so we use a per-server heuristic
    and flag it explicitly in `note`."""
    candidates = [
        (home / ".claude.json",                 "user"),
        (home / ".claude" / "settings.json",    "user"),
        (cwd / ".claude" / "settings.json",     "project"),
        (cwd / ".claude" / "settings.local.json", "project"),
        (cwd / ".mcp.json",                     "project"),
    ]
    sources: list[Source] = []
    seen = set()
    for path, scope in candidates:
        if not path.is_file():
            continue
        try:
            data = json.loads(read_text_safe(path))
        except Exception:
            continue
        servers = data.get("mcpServers") if isinstance(data, dict) else None
        if not isinstance(servers, dict):
            continue
        for name, cfg in servers.items():
            key = (name, scope)
            if key in seen:
                continue
            seen.add(key)
            # bytes of config = visible cost; tool schemas are the
            # invisible cost we can't measure
            cfg_chars = len(json.dumps(cfg, separators=(",", ":"))) if cfg else 0
            sources.append(Source(
                category="mcp",
                name=name,
                scope=scope,
                path=str(path),
                chars=cfg_chars,
                tokens=MCP_TOOLS_HEURISTIC_TOKENS,
                note=f"~{MCP_TOOLS_HEURISTIC_TOKENS} tok (schema not measured)",
            ))
    return sources


# ---------- CLAUDE.md discovery ----------

def discover_claude_md(home: Path, cwd: Path) -> list[Source]:
    candidates: list[tuple[Path, str]] = [
        (home / ".claude" / "CLAUDE.md", "user"),
        (cwd / "CLAUDE.md", "project"),
        (cwd / ".claude" / "CLAUDE.md", "project"),
    ]
    sources: list[Source] = []
    seen: set[Path] = set()
    for path, scope in candidates:
        try:
            resolved = path.resolve()
        except Exception:
            continue
        if not path.is_file() or resolved in seen:
            continue
        seen.add(resolved)
        text = read_text_safe(path)
        if not text:
            continue
        chars = len(text)
        sources.append(Source(
            category="claude_md",
            name=path.name if scope == "user" else f"{scope}/CLAUDE.md",
            scope=scope,
            path=str(path),
            chars=chars,
            tokens=tokens_for(chars),
        ))
    return sources


# ---------- Skills discovery ----------

def _skill_cost(name: str, description: str) -> int:
    # mirrors skill-budget's char_cost: name + ': ' + description + '\n'
    return len(name) + 2 + len(description) + 1


def discover_skills(home: Path, cwd: Path) -> list[Source]:
    sources: list[Source] = []
    seen: set[Path] = set()

    def scan(base: Path, scope: str):
        if not base.is_dir():
            return
        for skill_md in list(base.glob("*/SKILL.md")) + list(base.glob("*/*/SKILL.md")):
            try:
                rp = skill_md.resolve()
            except Exception:
                continue
            if rp in seen:
                continue
            seen.add(rp)
            name, desc = parse_frontmatter(read_text_safe(skill_md))
            if not name:
                name = skill_md.parent.name
            chars = _skill_cost(name, desc)
            sources.append(Source(
                category="skill",
                name=name,
                scope=scope,
                path=str(skill_md),
                chars=chars,
                tokens=tokens_for(chars),
            ))

    scan(home / ".claude" / "skills", "user")
    scan(cwd / ".claude" / "skills", "project")
    plugins_root = home / ".claude" / "plugins"
    if plugins_root.is_dir():
        for plugin_dir in plugins_root.iterdir():
            if plugin_dir.is_dir():
                scan(plugin_dir / "skills", "plugin")
    return sources


# ---------- Agents + commands discovery ----------

def _scan_md_dir(base: Path, scope: str, category: str) -> list[Source]:
    out: list[Source] = []
    if not base.is_dir():
        return out
    for md in sorted(base.glob("*.md")):
        text = read_text_safe(md)
        if not text:
            continue
        name, desc = parse_frontmatter(text)
        if not name:
            name = md.stem
        # Cost approximation: same shape as skills (name + description)
        chars = len(name) + 2 + len(desc) + 1
        out.append(Source(
            category=category,
            name=name,
            scope=scope,
            path=str(md),
            chars=chars,
            tokens=tokens_for(chars),
        ))
    return out


def discover_agents(home: Path, cwd: Path) -> list[Source]:
    return (_scan_md_dir(home / ".claude" / "agents", "user", "agent")
            + _scan_md_dir(cwd / ".claude" / "agents", "project", "agent"))


def discover_commands(home: Path, cwd: Path) -> list[Source]:
    return (_scan_md_dir(home / ".claude" / "commands", "user", "command")
            + _scan_md_dir(cwd / ".claude" / "commands", "project", "command"))


# ---------- aggregate + render ----------

CATEGORY_LABELS = {
    "mcp":       "MCP servers",
    "claude_md": "CLAUDE.md",
    "skill":     "Skills",
    "agent":     "Subagents",
    "command":   "Slash commands",
}


def discover_all(home: Path, cwd: Path) -> list[Source]:
    return (
        discover_mcp(home, cwd)
        + discover_claude_md(home, cwd)
        + discover_skills(home, cwd)
        + discover_agents(home, cwd)
        + discover_commands(home, cwd)
    )


def group_totals(sources: Iterable[Source]) -> dict[str, dict[str, int]]:
    out: dict[str, dict[str, int]] = {}
    for s in sources:
        bucket = out.setdefault(s.category, {"count": 0, "chars": 0, "tokens": 0})
        bucket["count"] += 1
        bucket["chars"] += s.chars
        bucket["tokens"] += s.tokens
    return out


def render_bar(value: int, total: int, width: int, c: Color, tinted: bool = True) -> str:
    if total <= 0:
        return c.dim("·" * width)
    ratio = min(value / total, 1.0)
    filled = int(ratio * width)
    bar = "█" * filled + c.dim("░") * (width - filled)
    if not tinted:
        return bar
    if ratio < 0.10:
        return c.green(bar)
    if ratio < 0.30:
        return c.cyan(bar)
    if ratio < 0.60:
        return c.amber(bar)
    return c.red(bar)


def top_cuts(sources: list[Source], n: int = 3) -> list[Source]:
    # Don't suggest cutting CLAUDE.md (user-curated) by default — focus
    # on auto-loaded skills/agents/MCP that are the most likely to be
    # cruft.
    cuttable = [s for s in sources if s.category in ("mcp", "skill", "agent", "command")]
    return sorted(cuttable, key=lambda s: s.tokens, reverse=True)[:n]


def cut_hint(s: Source) -> str:
    if s.category == "mcp":
        return f"remove '{s.name}' from {Path(s.path).name}"
    if s.category == "skill":
        return f"mv {s.path} {s.path}.disabled"
    if s.category == "agent":
        return f"mv {s.path} {s.path}.disabled"
    if s.category == "command":
        return f"mv {s.path} {s.path}.disabled"
    return f"# disable {s.name}"


def main():
    p = argparse.ArgumentParser(description="X-ray Claude Code's auto-injected context.")
    p.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    p.add_argument("--no-color", action="store_true", help="Disable ANSI colors")
    p.add_argument("--cwd", type=str, default=None,
                   help="Project directory to audit (default: current dir)")
    p.add_argument("--home", type=str, default=None,
                   help="Home directory to audit (default: $HOME)")
    args = p.parse_args()

    cwd = Path(args.cwd).resolve() if args.cwd else Path.cwd()
    home = Path(args.home).resolve() if args.home else Path.home()
    use_color = (not args.no_color) and sys.stdout.isatty() and not args.json
    c = Color(use_color)

    sources = discover_all(home, cwd)
    sources.sort(key=lambda s: s.tokens, reverse=True)
    totals = group_totals(sources)
    grand_total = sum(b["tokens"] for b in totals.values())

    if args.json:
        out = {
            "total_tokens": grand_total,
            "chars_per_token": CHARS_PER_TOKEN,
            "by_category": {
                cat: {**vals, "label": CATEGORY_LABELS.get(cat, cat)}
                for cat, vals in totals.items()
            },
            "sources": [asdict(s) for s in sources],
            "top_cuts": [
                {"name": s.name, "category": s.category, "tokens": s.tokens,
                 "hint": cut_hint(s)}
                for s in top_cuts(sources)
            ],
        }
        print(json.dumps(out, indent=2))
        return

    print(c.bold("token-x-ray — auto-injected context audit"))
    print(c.dim("─" * 60))
    print(f"Project: {cwd}")
    print(f"Home:    {home}")
    print()
    print(c.bold(f"Total estimated: {grand_total:,} tokens  ")
          + c.dim(f"(@ {CHARS_PER_TOKEN} chars/token)"))
    print()

    if not sources:
        print(c.dim("No auto-injected context discovered."))
        print(c.dim("This means no skills, agents, commands, MCP servers,"))
        print(c.dim("or CLAUDE.md files were found in standard locations."))
        return

    # Category roll-up
    print(c.bold("By category:"))
    cat_max = max(b["tokens"] for b in totals.values()) if totals else 1
    for cat in sorted(totals.keys(), key=lambda k: totals[k]["tokens"], reverse=True):
        b = totals[cat]
        label = CATEGORY_LABELS.get(cat, cat)
        bar = render_bar(b["tokens"], cat_max, 24, c, tinted=False)
        print(f"  {label:<16}  {bar}  {b['tokens']:>6,} tok  "
              + c.dim(f"({b['count']} item{'s' if b['count'] != 1 else ''})"))
    print()

    # Per-source rows (top 15)
    print(c.bold("Top sources (by tokens):"))
    src_max = sources[0].tokens if sources else 1
    for s in sources[:15]:
        bar = render_bar(s.tokens, src_max, 18, c)
        name = s.name[:30]
        cat = CATEGORY_LABELS.get(s.category, s.category)[:14]
        scope = s.scope[:7]
        note = c.dim(f"  {s.note}") if s.note else ""
        print(f"  {name:<30}  {cat:<14}  {scope:<7}  {bar}  "
              f"{s.tokens:>5,} tok{note}")
    if len(sources) > 15:
        print(c.dim(f"  ... and {len(sources) - 15} more (use --json for full list)"))
    print()

    # Top cuts
    cuts = top_cuts(sources, n=3)
    if cuts:
        savings = sum(s.tokens for s in cuts)
        print(c.bold(f"Top cuts (potential savings: ~{savings:,} tokens):"))
        for s in cuts:
            print(f"  {c.amber('→')} {s.name}  "
                  + c.dim(f"({s.tokens:,} tok, {s.category})"))
            print(f"      {c.dim(cut_hint(s))}")
        print()

    # Unmeasured-MCP warning
    mcp_count = totals.get("mcp", {}).get("count", 0)
    if mcp_count:
        print(c.amber(f"⚠ {mcp_count} MCP server(s) declared. Token cost is a "
                      f"heuristic ({MCP_TOOLS_HEURISTIC_TOKENS} tok each)."))
        print(c.dim("  Run /context inside Claude Code for the authoritative number."))


if __name__ == "__main__":
    main()
