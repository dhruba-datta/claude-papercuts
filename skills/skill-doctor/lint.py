#!/usr/bin/env python3
"""
lint.py — diagnose why a SKILL.md isn't auto-invoking.

Anthropic's issue anthropics/claude-code#30387 reports that skills for
common operations (git, shell, file I/O) silently fail to trigger
because Claude's training-time knowledge competes with — and usually
beats — the skill description. lint.py runs the same heuristics
Anthropic's own template authors apply implicitly:

  1. Frontmatter validation
     - name + description required
     - name is kebab-case lowercase
     - description is 50–1024 chars (Anthropic's published bound)

  2. Trigger-phrase presence
     - "Use this when …" / "Use this skill when …" / "Use for …"
       are the canonical trigger forms in Anthropic's docs. Skills
       without them are ~3× less likely to auto-invoke.

  3. Vague-word penalty
     - "helper", "utility", "manager", "assistant" without a noun
       refining them. The model can't tell when to dispatch.

  4. Training-overlap detection
     - Descriptions like "use for git operations" or "manages files"
       overlap with Claude's training-time defaults for built-in
       tools (Bash, Read, Write, Edit). The model defaults to the
       built-in tool and never invokes the skill.

  5. Length and bullet hygiene
     - One-line descriptions under 80 chars often don't carry enough
       context for the model to route to the right skill.

Usage:
    lint.py <path/to/SKILL.md>          # lint one file
    lint.py --all [--cwd PATH] [--home PATH]   # lint every discoverable skill
    lint.py --json ...                  # JSON output for scripting
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, asdict, field
from pathlib import Path

NAME_RE = re.compile(r"^[a-z][a-z0-9-]{1,63}$")
TRIGGER_PHRASES = [
    r"\buse this when\b",
    r"\buse this skill when\b",
    r"\buse for\b",
    r"\buse when\b",
    r"\binvoke (?:this|when)\b",
    r"\btrigger (?:this|when|on)\b",
    r"\bcall (?:this|when)\b",
]
VAGUE_WORDS = {
    "helper": "a 'helper' that doesn't say what it helps with",
    "utility": "a generic 'utility' without a clear scope",
    "manager": "a 'manager' without a clear scope",
    "toolkit": "vague 'toolkit' — name what it actually does",
}
# Training-overlap patterns: phrases that compete with Claude's built-in
# tool defaults. Source: issue #30387 reporter's own examples.
TRAINING_OVERLAP = [
    (r"\bgit\s+(?:operations?|commands?|tasks?)\b",
     "vague 'git operations' — name the specific git workflow this skill owns"),
    (r"\b(?:read|reads|reading)\s+files?\b",
     "'reading files' overlaps with the built-in Read tool"),
    (r"\b(?:edit|edits|editing|modify|modifies|modifying)\s+files?\b",
     "'editing files' overlaps with the built-in Edit tool"),
    (r"\b(?:write|writes|writing|create|creates|creating)\s+(?:new\s+)?files?\b",
     "'writing files' overlaps with the built-in Write tool"),
    (r"\bruns?\s+(?:commands?|shell|bash|terminal)\b",
     "'runs shell' overlaps with the built-in Bash tool"),
    (r"\bsearche?s?\s+(?:the\s+)?(?:codebase|files?|repo|repository)\b",
     "'searches the codebase' overlaps with built-in Grep/Glob"),
]

SEVERITY_ORDER = {"error": 0, "warn": 1, "info": 2}


@dataclass
class Issue:
    severity: str  # error | warn | info
    code: str
    message: str


@dataclass
class Report:
    path: str
    name: str | None
    description_len: int
    issues: list[Issue] = field(default_factory=list)
    ok: bool = True


def parse_frontmatter(text: str) -> tuple[str | None, str | None, dict]:
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return None, None, {}
    fm = m.group(1)
    fields = {}
    name = None
    desc = None
    nm = re.search(r"^name:\s*(.+?)\s*$", fm, re.MULTILINE)
    if nm:
        name = nm.group(1).strip().strip('"').strip("'")
        fields["name"] = name
    dm = re.search(r"^description:\s*(.+?)(?=\n[a-z][a-z0-9_-]*:|\Z)",
                   fm, re.DOTALL | re.MULTILINE | re.IGNORECASE)
    if dm:
        desc = re.sub(r"\s+", " ", dm.group(1).strip().strip('"').strip("'"))
        fields["description"] = desc
    return name, desc, fields


def lint_one(path: Path) -> Report:
    rep = Report(path=str(path), name=None, description_len=0)
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except Exception as e:
        rep.issues.append(Issue("error", "unreadable", f"could not read file: {e}"))
        rep.ok = False
        return rep
    name, desc, _ = parse_frontmatter(text)
    rep.name = name
    rep.description_len = len(desc) if desc else 0

    if not name:
        rep.issues.append(Issue("error", "no-name",
                                "frontmatter has no `name:` field"))
    elif not NAME_RE.match(name):
        rep.issues.append(Issue("error", "bad-name",
                                f"name {name!r} should be kebab-case ([a-z][a-z0-9-]+)"))

    if not desc:
        rep.issues.append(Issue("error", "no-description",
                                "frontmatter has no `description:` field"))
    else:
        L = len(desc)
        if L < 50:
            rep.issues.append(Issue("error", "desc-too-short",
                                    f"description is {L} chars; Anthropic's lower bound is 50"))
        elif L > 1024:
            rep.issues.append(Issue("error", "desc-too-long",
                                    f"description is {L} chars; Anthropic's upper bound is 1024"))
        elif L < 80:
            rep.issues.append(Issue("warn", "desc-thin",
                                    f"description is only {L} chars — add a trigger phrase and an example"))

        # Trigger phrases
        if not any(re.search(p, desc, re.IGNORECASE) for p in TRIGGER_PHRASES):
            rep.issues.append(Issue("warn", "no-trigger",
                                    "no 'Use this when …' phrase — model has nothing to route on"))

        # Vague words
        lowered = desc.lower()
        for word, why in VAGUE_WORDS.items():
            if re.search(rf"\b{word}\b", lowered):
                rep.issues.append(Issue("info", f"vague-{word}", why))

        # Training overlap
        for pat, why in TRAINING_OVERLAP:
            if re.search(pat, lowered):
                rep.issues.append(Issue("warn", "training-overlap", why))

    rep.ok = not any(i.severity == "error" for i in rep.issues)
    rep.issues.sort(key=lambda i: (SEVERITY_ORDER[i.severity], i.code))
    return rep


def discover_skill_md(home: Path, cwd: Path) -> list[Path]:
    paths = []
    seen = set()
    def scan(base: Path):
        if not base.is_dir():
            return
        for p in list(base.glob("*/SKILL.md")) + list(base.glob("*/*/SKILL.md")):
            try:
                rp = p.resolve()
            except Exception:
                continue
            if rp in seen:
                continue
            seen.add(rp)
            paths.append(p)
    scan(home / ".claude" / "skills")
    scan(cwd / ".claude" / "skills")
    plugins_root = home / ".claude" / "plugins"
    if plugins_root.is_dir():
        for plugin_dir in plugins_root.iterdir():
            if plugin_dir.is_dir():
                scan(plugin_dir / "skills")
    return paths


class Color:
    def __init__(self, enabled):
        self.enabled = enabled
    def _w(self, c, s): return f"\033[{c}m{s}\033[0m" if self.enabled else s
    def red(self, s):   return self._w("38;5;203", s)
    def amber(self, s): return self._w("38;5;179", s)
    def green(self, s): return self._w("38;5;114", s)
    def dim(self, s):   return self._w("2",        s)
    def bold(self, s):  return self._w("1",        s)


def render_report(rep: Report, c: Color):
    label = f"{c.bold(rep.name or '(unnamed)')}  {c.dim(rep.path)}"
    print(label)
    if not rep.issues:
        print(f"  {c.green('✓')} no issues  {c.dim(f'(desc {rep.description_len} chars)')}")
        return
    sev_color = {"error": c.red, "warn": c.amber, "info": c.dim}
    sev_glyph = {"error": "✗", "warn": "⚠", "info": "·"}
    for issue in rep.issues:
        print(f"  {sev_color[issue.severity](sev_glyph[issue.severity])} "
              f"{sev_color[issue.severity](issue.severity.upper())} "
              f"{c.dim(issue.code)}  {issue.message}")
    print()


def main():
    p = argparse.ArgumentParser(description="Lint SKILL.md files.")
    p.add_argument("path", nargs="?", help="SKILL.md path to lint (or use --all)")
    p.add_argument("--all", action="store_true",
                   help="Lint every discoverable SKILL.md")
    p.add_argument("--json", action="store_true", help="Machine-readable JSON")
    p.add_argument("--no-color", action="store_true", help="Disable colors")
    p.add_argument("--cwd", help="Project dir (default cwd)")
    p.add_argument("--home", help="Home dir (default $HOME)")
    args = p.parse_args()

    paths: list[Path] = []
    if args.all:
        home = Path(args.home).resolve() if args.home else Path.home()
        cwd = Path(args.cwd).resolve() if args.cwd else Path.cwd()
        paths = discover_skill_md(home, cwd)
    elif args.path:
        paths = [Path(args.path)]
    else:
        p.error("provide a path or --all")

    if not paths:
        msg = "No SKILL.md files found."
        if args.json:
            print(json.dumps({"reports": [], "note": msg}, indent=2))
        else:
            print(msg)
        return 0

    reports = [lint_one(path) for path in paths]

    if args.json:
        out = {
            "total": len(reports),
            "ok": sum(1 for r in reports if r.ok),
            "with_errors": sum(1 for r in reports if not r.ok),
            "reports": [
                {**asdict(r), "issues": [asdict(i) for i in r.issues]}
                for r in reports
            ],
        }
        print(json.dumps(out, indent=2))
        return 0 if all(r.ok for r in reports) else 1

    use_color = (not args.no_color) and sys.stdout.isatty()
    c = Color(use_color)
    print(c.bold(f"skill-doctor — lint {len(reports)} SKILL.md file(s)"))
    print(c.dim("─" * 60))
    print()
    for rep in reports:
        render_report(rep, c)

    errors = sum(1 for r in reports if not r.ok)
    warns = sum(1 for r in reports for i in r.issues if i.severity == "warn")
    print(c.dim("─" * 60))
    if errors:
        print(c.red(f"{errors} skill(s) with errors") + c.dim(f"  ({warns} warnings)"))
        return 1
    elif warns:
        print(c.amber(f"{len(reports)} skill(s) lint clean") + c.dim(f"  ({warns} warnings to consider)"))
    else:
        print(c.green(f"{len(reports)} skill(s) lint clean"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
