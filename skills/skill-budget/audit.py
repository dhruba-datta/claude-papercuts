#!/usr/bin/env python3
"""
audit.py — find every installed Claude Code skill, parse its SKILL.md
frontmatter, and report how many characters they collectively inject
into the system prompt vs the (configurable) char budget.

The exact char budget for skill descriptions is not officially
documented by Anthropic. Issues anthropics/claude-code#30387, #34648,
#16575 describe symptoms consistent with a budget around 15,000 chars
above which skills silently fall out of the system prompt. We treat
15,000 as the default and let the user override it.

Usage:
    audit.py [--budget N] [--json] [--no-color]

By default, scans:
    ~/.claude/skills/<name>/SKILL.md
    <cwd>/.claude/skills/<name>/SKILL.md
    ~/.claude/plugins/**/skills/<name>/SKILL.md
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterator

DEFAULT_BUDGET = 15_000
WARN_RATIO = 0.80  # amber starts at 80% of budget

# ANSI color codes — used only when stdout is a tty
class Color:
    def __init__(self, enabled: bool):
        self.enabled = enabled

    def _wrap(self, code: str, s: str) -> str:
        return f"\033[{code}m{s}\033[0m" if self.enabled else s

    def green(self, s):  return self._wrap("38;5;114", s)
    def amber(self, s):  return self._wrap("38;5;179", s)
    def red(self, s):    return self._wrap("38;5;203", s)
    def dim(self, s):    return self._wrap("2",        s)
    def bold(self, s):   return self._wrap("1",        s)


@dataclass
class Skill:
    name: str           # from frontmatter or folder name
    description: str    # from frontmatter
    path: str           # absolute path to SKILL.md
    source: str         # "user" | "project" | "plugin"
    char_cost: int      # estimated chars injected into system prompt


def parse_frontmatter(path: Path) -> tuple[str | None, str | None]:
    """Return (name, description) from a SKILL.md, or (None, None) on any error."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return None, None
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return None, None
    fm = m.group(1)
    name = None
    description = None
    name_m = re.search(r"^name:\s*(.+?)\s*$", fm, re.MULTILINE)
    if name_m:
        name = name_m.group(1).strip().strip('"').strip("'")
    # description can span multiple lines; capture until next YAML key or end
    desc_m = re.search(r"^description:\s*(.+?)(?=\n[a-z][a-z0-9_-]*:|\Z)",
                       fm, re.DOTALL | re.MULTILINE | re.IGNORECASE)
    if desc_m:
        description = desc_m.group(1).strip().strip('"').strip("'")
        # collapse internal newlines + extra whitespace
        description = re.sub(r"\s+", " ", description)
    return name, description


def char_cost(name: str, description: str) -> int:
    """Approximate chars this skill costs in the system prompt.
    Format roughly: 'name: description\n' per skill."""
    return len(name) + 2 + len(description) + 1


def find_skills() -> Iterator[Skill]:
    """Yield Skill objects from every known location."""
    seen_paths: set[Path] = set()

    def scan(base: Path, source: str):
        if not base.exists() or not base.is_dir():
            return
        # Skills live at <base>/<skill-name>/SKILL.md, but some plugin
        # layouts go a level deeper. Glob both depths.
        for skill_md in list(base.glob("*/SKILL.md")) + list(base.glob("*/*/SKILL.md")):
            resolved = skill_md.resolve()
            if resolved in seen_paths:
                continue
            seen_paths.add(resolved)
            name, description = parse_frontmatter(skill_md)
            if not name:
                # fall back to folder name
                name = skill_md.parent.name
            if description is None:
                description = ""
            yield Skill(
                name=name,
                description=description,
                path=str(skill_md),
                source=source,
                char_cost=char_cost(name, description),
            )

    home = Path.home()
    yield from scan(home / ".claude" / "skills", "user")

    cwd = Path.cwd()
    yield from scan(cwd / ".claude" / "skills", "project")

    plugins_root = home / ".claude" / "plugins"
    if plugins_root.is_dir():
        for plugin_dir in plugins_root.iterdir():
            if plugin_dir.is_dir():
                yield from scan(plugin_dir / "skills", "plugin")


def render_bar(used: int, total: int, width: int = 50, c: Color = None) -> str:
    """Unicode block-character progress bar with red/amber/green tinting."""
    c = c or Color(False)
    ratio = min(used / total, 1.0) if total > 0 else 0.0
    filled = int(ratio * width)
    empty = width - filled
    bar = "█" * filled + c.dim("░") * empty
    if ratio < WARN_RATIO:
        bar = c.green(bar)
    elif ratio < 1.0:
        bar = c.amber(bar)
    else:
        bar = c.red(bar)
    return bar


def render_skill_row(skill: Skill, max_bar: int, max_cost: int, budget: int,
                     running_total: int, c: Color) -> str:
    name = skill.name[:24].ljust(24)
    bar_chars = int((skill.char_cost / max_cost) * max_bar) if max_cost else 0
    bar = "█" * bar_chars
    cost = f"{skill.char_cost:>5} ch"
    if running_total > budget:
        status = c.red("✗ INVISIBLE")
    elif running_total > budget * WARN_RATIO:
        status = c.amber("⚠ at risk")
    else:
        status = c.green("✓ visible ")
    return f"  {name}  {bar:<24}  {cost}  {status}"


def main():
    p = argparse.ArgumentParser(description="Audit Claude Code skill budget.")
    p.add_argument("--budget", type=int, default=DEFAULT_BUDGET,
                   help=f"Char budget for skill descriptions (default {DEFAULT_BUDGET})")
    p.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    p.add_argument("--no-color", action="store_true", help="Disable ANSI colors")
    args = p.parse_args()

    use_color = (not args.no_color) and sys.stdout.isatty()
    c = Color(use_color)

    skills = sorted(find_skills(), key=lambda s: s.char_cost, reverse=True)
    total = sum(s.char_cost for s in skills)
    pct = (total / args.budget * 100) if args.budget else 0

    # Mark each skill visible / at-risk / invisible based on a cumulative sum
    # (skills are sorted high-cost first; once cumulative > budget, the rest
    #  are practically invisible).
    cumulative = 0
    annotated = []
    for s in skills:
        cumulative += s.char_cost
        if cumulative > args.budget:
            status = "invisible"
        elif cumulative > args.budget * WARN_RATIO:
            status = "at-risk"
        else:
            status = "visible"
        annotated.append((s, status, cumulative))

    invisible = [s for s, status, _ in annotated if status == "invisible"]
    at_risk = [s for s, status, _ in annotated if status == "at-risk"]

    if args.json:
        out = {
            "budget": args.budget,
            "total_chars": total,
            "usage_pct": round(pct, 1),
            "skill_count": len(skills),
            "invisible_count": len(invisible),
            "skills": [
                {**asdict(s), "status": status, "cumulative_after": cum}
                for s, status, cum in annotated
            ],
        }
        print(json.dumps(out, indent=2))
        return

    # Text output
    print(c.bold("Skill budget audit"))
    print(c.dim("─" * 60))
    print(f"Budget:  {args.budget:,} chars (override with --budget)")
    print(f"Usage:   {total:,} chars  ({pct:.1f}%)")
    print()
    print("  " + render_bar(total, args.budget, width=50, c=c)
          + f"  {total:,} / {args.budget:,}")
    print()

    if not skills:
        print(c.dim("No skills found in ~/.claude/skills, .claude/skills,"))
        print(c.dim("or ~/.claude/plugins/*/skills/."))
        return

    # Source breakdown
    by_source: dict[str, int] = {}
    for s in skills:
        by_source[s.source] = by_source.get(s.source, 0) + 1
    print(f"{len(skills)} skills across {len(by_source)} source(s):")
    for src, count in sorted(by_source.items()):
        print(f"  {src:<10}  {count} skill(s)")
    print()

    # Per-skill table (sorted by char weight)
    print(c.bold("By char weight:"))
    max_cost = max(s.char_cost for s in skills)
    for s, _, cum in annotated:
        print(render_skill_row(s, 18, max_cost, args.budget, cum, c))
    print()

    # Invisibility warning
    if invisible:
        print(c.red(f"{len(invisible)} skill(s) are INVISIBLE TO CLAUDE right now:"))
        for s in invisible:
            print(c.red(f"  ✗ {s.name}") + c.dim(f"  ({s.path})"))
        print()
        print(c.bold("Suggested actions:"))
        print(c.dim("  Disable a skill by renaming its SKILL.md:"))
        for s in invisible[:3]:
            print(c.dim(f"    mv {s.path} {s.path}.disabled"))
        if len(invisible) > 3:
            print(c.dim(f"    ...and {len(invisible) - 3} more"))
    elif at_risk:
        print(c.amber(f"You are at {pct:.0f}% of the budget. "
                      f"{len(at_risk)} skill(s) may be at risk if you add more."))
    else:
        print(c.green(f"All {len(skills)} skill(s) fit comfortably under the budget."))


if __name__ == "__main__":
    main()
