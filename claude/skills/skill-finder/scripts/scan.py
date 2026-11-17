#!/usr/bin/env python3
"""
skill-finder scan.py — Dynamic skill discovery engine.

Reads all installed Claude Code skills, builds keyword profiles from their
SKILL.md content, and scores them against the project context using
IDF-weighted matching. No hardcoded keyword maps — fully dynamic.

Usage:
    python3 scan.py <project_path>                    # Analyze and suggest
    python3 scan.py <project_path> --write "s1,s2,s3" # Write approved skills
"""

import sys
import re
import json
from pathlib import Path
from datetime import datetime, date
from collections import Counter

# ─── Constants ───────────────────────────────────────────────────────────────

SKILLS_DIR = Path.home() / ".claude" / "skills"
MARKER_START = "<!-- skill-finder:start -->"
MARKER_END = "<!-- skill-finder:end -->"
MAX_SUGGESTIONS = 7
MIN_SCORE = 5
DIRECT_NAME_BONUS = 5

# Short but meaningful technical signals (bypass min_length filter)
SHORT_SIGNALS = {
    "ui", "ux", "ai", "ml", "seo", "api", "css", "ci", "cd",
    "db", "qa", "bi", "iot", "ar", "vr", "3d", "2d", "pdf",
    "svg", "jwt", "orm", "cdn", "dns", "ssh", "ssl", "tls",
    "pwa", "ssr", "ssg", "rpc", "ddd", "tdd", "bdd", "cms",
    "geo", "crm", "erp", "b2b", "b2c", "mvp", "sdk", "cli",
    "llm", "rag", "nlp", "ocr", "e2e",
}

# Stop words filtered from both skill profiles and project context
STOP_WORDS = {
    # English function words
    "this", "that", "with", "from", "have", "will", "your", "when",
    "what", "which", "their", "about", "would", "there", "been", "could",
    "into", "than", "them", "each", "make", "like", "does", "also",
    "just", "over", "such", "take", "only", "come", "made", "after",
    "used", "using", "uses", "file", "code", "should", "must",
    "true", "false", "none", "null", "type", "name", "path",
    "based", "need", "built", "work", "data", "want", "more",
    "best", "good", "well", "very", "then", "here", "some",
    "tool", "tools", "skill", "skills", "before", "first", "last",
    "most", "other", "where", "being", "both", "same", "under",
    "above", "below", "between", "through", "during", "while",
    "again", "further", "once", "many", "much", "every", "still",
    "example", "ensure", "check", "following", "provides", "includes",
    "always", "never", "write", "read", "create", "update", "delete",
    "show", "display", "output", "input", "result", "return",
    "function", "method", "class", "variable", "parameter",
    "note", "important", "default", "value", "string", "number",
    "list", "dict", "array", "object", "module", "package",
    "command", "option", "argument", "flag", "config", "setting",
    "when", "user", "says", "invoke", "invoke", "activate",
    # Generic SKILL.md words
    "skill", "claude", "agent", "prompt", "context", "response",
    "step", "steps", "rule", "rules", "section", "markdown",
    "format", "output", "instruction", "instructions",
}

# Tech stack files → signals to inject into project context
TECH_STACK_FILES = {
    "package.json": ["javascript", "node", "npm"],
    "requirements.txt": ["python", "pip"],
    "Pipfile": ["python", "pipenv"],
    "pyproject.toml": ["python"],
    "Cargo.toml": ["rust", "cargo"],
    "go.mod": ["golang"],
    "Gemfile": ["ruby"],
    "composer.json": ["php"],
    "pubspec.yaml": ["dart", "flutter"],
    "build.gradle": ["java", "gradle"],
    "build.gradle.kts": ["kotlin", "gradle"],
    "pom.xml": ["java", "maven"],
    "tsconfig.json": ["typescript"],
    "next.config.js": ["next.js", "react"],
    "next.config.ts": ["next.js", "react", "typescript"],
    "next.config.mjs": ["next.js", "react"],
    "nuxt.config.ts": ["nuxt", "vue", "typescript"],
    "nuxt.config.js": ["nuxt", "vue"],
    "vite.config.ts": ["vite", "typescript"],
    "vite.config.js": ["vite"],
    "svelte.config.js": ["svelte"],
    "angular.json": ["angular", "typescript"],
    "tailwind.config.js": ["tailwind", "css"],
    "tailwind.config.ts": ["tailwind", "css"],
    "docker-compose.yml": ["docker", "containers"],
    "docker-compose.yaml": ["docker", "containers"],
    "Dockerfile": ["docker"],
    ".github/workflows": ["ci/cd", "github-actions"],
    "supabase": ["supabase", "postgresql"],
    "prisma": ["prisma", "database"],
    "drizzle.config.ts": ["drizzle", "database", "typescript"],
}


# ─── Keyword Extraction ─────────────────────────────────────────────────────

def extract_keywords(text: str, min_length: int = 4) -> set[str]:
    """
    Extract meaningful keywords from text.

    Pulls words >= min_length chars, plus short technical signals
    (ui, ux, seo, api, etc.). Filters stop words.
    """
    lower = text.lower()

    # Standard words (min_length+ chars, starts with letter)
    words = set(re.findall(r"\b[a-z][a-z0-9]{" + str(min_length - 1) + r",}\b", lower))

    # Compound tech terms: next.js, vue.js, node.js, etc.
    words |= set(re.findall(r"[a-z]+\.js", lower))

    # Short signals: only if they appear as whole words
    for sig in SHORT_SIGNALS:
        if re.search(r"\b" + re.escape(sig) + r"\b", lower):
            words.add(sig)

    return words - STOP_WORDS


# ─── Skill Profile Building ─────────────────────────────────────────────────

def parse_frontmatter(path: Path) -> dict:
    """Read all frontmatter fields from SKILL.md."""
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except (OSError, UnicodeDecodeError):
        return {}

    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return {}

    fm = {}
    current_key = None
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if ":" in line and not line.startswith(" ") and not line.startswith("\t"):
            key, _, val = line.partition(":")
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            fm[key] = val
            current_key = key
        elif current_key and (line.startswith("  ") or line.startswith("\t")):
            # Multi-line value or YAML list items
            item = line.strip().lstrip("- ").strip('"').strip("'")
            if item:
                fm[current_key] = fm.get(current_key, "") + " " + item
    return fm


def extract_trigger_phrases(path: Path) -> str:
    """
    Extract high-signal 'trigger' lines from SKILL.md body.

    Only captures lines matching patterns like:
    - "Use when...", "Triggers on:", "Activate when..."
    - "Reference when...", "Use for..."
    - Bullet points under "When to Use" / "When This Skill Activates" headers

    This avoids ingesting the entire body (which adds noise from
    instructional text, code examples, and formatting).
    """
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except (OSError, UnicodeDecodeError):
        return ""

    lines = text.split("\n")
    trigger_lines = []
    in_frontmatter = False
    started = False
    capture_block = False

    trigger_patterns = re.compile(
        r"(use when|triggers? on|activate when|reference when|"
        r"use for|use this|works with|designed for|built for|"
        r"optimizes?|analyz|when .*(?:user|asks?|says?|wants?|mentions?))",
        re.IGNORECASE,
    )
    section_patterns = re.compile(
        r"^#+\s*(when to use|when this skill|activation|triggers?)\b",
        re.IGNORECASE,
    )

    for line in lines:
        if not started:
            if line.strip() == "---":
                if not in_frontmatter:
                    in_frontmatter = True
                else:
                    started = True
            continue

        stripped = line.strip()
        if not stripped:
            if capture_block:
                capture_block = False
            continue

        # Skip code blocks
        if stripped.startswith("```"):
            capture_block = False
            continue

        # Section header that indicates trigger content
        if section_patterns.match(stripped):
            capture_block = True
            continue

        # Capture bullets under trigger sections
        if capture_block and stripped.startswith("-"):
            trigger_lines.append(stripped.lstrip("- "))
            continue

        # Individual trigger lines anywhere in body
        if trigger_patterns.search(stripped):
            trigger_lines.append(stripped)

        if len(trigger_lines) >= 15:
            break

    return " ".join(trigger_lines)


def build_skill_profile(skill: dict) -> set[str]:
    """
    Build a keyword profile for a skill from curated sources:
    - Name parts (high signal)
    - Description (curated by skill author)
    - Tags (when present)
    - Trigger phrases from body (only "Use when...", etc.)

    Does NOT ingest the entire body to avoid noise from
    instructional text and code examples.
    """
    parts = []

    # Skill name split on hyphens
    name = skill.get("name", "")
    parts.append(name.replace("-", " "))

    # Description (richest curated signal)
    parts.append(skill.get("description", ""))

    # Tags (high quality when present)
    parts.append(skill.get("tags", ""))

    # Trigger phrases only (not the entire body)
    parts.append(skill.get("triggers", ""))

    all_text = " ".join(parts)
    keywords = extract_keywords(all_text)

    # Add full name and meaningful parts as keywords
    keywords.add(name.lower())
    for part in name.lower().split("-"):
        if len(part) >= 3 and part not in STOP_WORDS:
            keywords.add(part)

    return keywords


# ─── Skill Discovery ────────────────────────────────────────────────────────

def get_installed_skills() -> list[dict]:
    """Discover all installed skills from ~/.claude/skills/."""
    skills = []
    if not SKILLS_DIR.is_dir():
        return skills

    for skill_md in sorted(SKILLS_DIR.rglob("SKILL.md")):
        skill_dir = skill_md.parent
        # Skip skill-finder itself
        if skill_dir.name == "skill-finder":
            continue
        # Only direct children of skills/
        if skill_dir.parent != SKILLS_DIR:
            continue

        fm = parse_frontmatter(skill_md)
        name = fm.get("name", skill_dir.name)
        triggers = extract_trigger_phrases(skill_md)

        skills.append({
            "name": name,
            "dir_name": skill_dir.name,
            "description": fm.get("description", ""),
            "tags": fm.get("tags", ""),
            "triggers": triggers,
            "path": str(skill_md),
            "mtime": skill_md.stat().st_mtime,
        })
    return skills


# ─── Project Context ─────────────────────────────────────────────────────────

def get_project_context(project_path: Path) -> str:
    """
    Build project context from CLAUDE.md + lightweight tech stack detection.
    Returns concatenated text for keyword extraction.
    """
    parts = []

    # Read CLAUDE.md variants
    for name in ("CLAUDE.md", "claude.md", "CLAUDE.local.md"):
        p = project_path / name
        if p.is_file():
            try:
                parts.append(p.read_text(encoding="utf-8", errors="ignore"))
            except OSError:
                pass

    # Tech stack detection from project files
    detected_tech = []
    for filename, signals in TECH_STACK_FILES.items():
        target = project_path / filename
        if target.exists():
            detected_tech.extend(signals)

    # Parse package.json dependencies for richer signals
    pkg_json = project_path / "package.json"
    if pkg_json.is_file():
        try:
            pkg = json.loads(pkg_json.read_text(encoding="utf-8"))
            for key in ("dependencies", "devDependencies"):
                for dep_name in pkg.get(key, {}):
                    # Clean scoped package names: @scope/name → name
                    clean = dep_name.split("/")[-1] if "/" in dep_name else dep_name
                    detected_tech.append(clean)
        except (json.JSONDecodeError, OSError):
            pass

    if detected_tech:
        parts.append("[tech-stack]: " + " ".join(set(detected_tech)))

    return "\n".join(parts)


def read_claude_md(project_path: Path) -> tuple[str, Path | None]:
    """Find and read the project's CLAUDE.md. Returns (content, path)."""
    for name in ("CLAUDE.md", "claude.md", "CLAUDE.local.md"):
        p = project_path / name
        if p.is_file():
            try:
                return p.read_text(encoding="utf-8", errors="ignore"), p
            except OSError:
                pass
    return "", None


# ─── State Management ────────────────────────────────────────────────────────

def get_last_scan_date(content: str) -> float:
    """Extract last scan timestamp from skill-finder markers."""
    pattern = re.escape(MARKER_START) + r"\s+(\d{4}-\d{2}-\d{2})"
    m = re.search(pattern, content)
    if m:
        try:
            return datetime.strptime(m.group(1), "%Y-%m-%d").timestamp()
        except ValueError:
            pass
    return 0.0


def get_active_skills(content: str) -> list[str]:
    """Extract currently active skills from the skill-finder block."""
    start = content.find(MARKER_START)
    end = content.find(MARKER_END)
    if start == -1 or end == -1:
        return []
    block = content[start:end]
    m = re.search(r"Skill attive:\s*(.+)", block)
    if m:
        return [s.strip() for s in m.group(1).split(",") if s.strip()]
    return []


def has_new_skills_since(skills: list[dict], last_scan: float) -> list[dict]:
    """Filter skills installed or modified after the last scan."""
    if last_scan <= 0:
        return []
    return [s for s in skills if s["mtime"] > last_scan]


# ─── IDF-Weighted Scoring ────────────────────────────────────────────────────

def score_skills(project_context: str, installed_skills: list[dict]) -> list[dict]:
    """
    Score installed skills against the project context using IDF-weighted
    keyword matching. Fully dynamic — no hardcoded keyword maps.

    IDF weighting:
    - Words in ≤10% of skills → weight 3 (very distinctive)
    - Words in ≤25% of skills → weight 2 (uncommon)
    - Words in ≤50% of skills → weight 1 (moderate)
    - Words in >50% of skills → weight 0 (too generic, skip)

    Bonus: +5 if the skill name appears directly in the project context.
    """
    # Build keyword profiles for all skills
    skill_profiles: dict[str, set[str]] = {}
    word_doc_freq: Counter = Counter()

    for skill in installed_skills:
        profile = build_skill_profile(skill)
        skill_profiles[skill["name"]] = profile
        for word in profile:
            word_doc_freq[word] += 1

    total_skills = max(len(installed_skills), 1)

    # Build project keyword profile
    project_keywords = extract_keywords(project_context)
    project_lower = project_context.lower()

    results = []

    for skill in installed_skills:
        name = skill["name"]
        profile = skill_profiles[name]
        overlap = profile & project_keywords

        if not overlap:
            continue

        score = 0
        matched = []

        # Direct name match bonus (strongest signal)
        name_lower = name.lower()
        dir_lower = skill["dir_name"].lower()
        if (
            re.search(r"\b" + re.escape(name_lower) + r"\b", project_lower)
            or (dir_lower != name_lower and re.search(r"\b" + re.escape(dir_lower) + r"\b", project_lower))
        ):
            score += DIRECT_NAME_BONUS
            matched.append(f"'{name}' in project")

        # IDF-weighted keyword scoring
        for word in sorted(overlap):
            df = word_doc_freq.get(word, 1)
            ratio = df / total_skills

            if ratio <= 0.05:
                weight = 3  # very rare: in ≤5% of skills
            elif ratio <= 0.15:
                weight = 2  # uncommon: ≤15%
            elif ratio <= 0.30:
                weight = 1  # moderate: ≤30%
            else:
                weight = 0  # too common: >30%, skip

            if weight > 0:
                score += weight
                if len(matched) < 5:
                    matched.append(word)

        if score >= MIN_SCORE:
            results.append({
                "name": name,
                "score": score,
                "keywords": matched,
                "description": skill["description"],
            })

    results.sort(key=lambda x: -x["score"])
    return results[:MAX_SUGGESTIONS]


# ─── Output Formatting ───────────────────────────────────────────────────────

def format_output(
    suggestions: list[dict],
    new_skills: list[dict],
    active_skills: list[str],
    project_path: Path,
) -> str:
    """Format scan results for Claude to interpret and present conversationally."""
    project_name = project_path.name
    today = date.today().isoformat()

    lines = [f"[skill-finder] Scansione progetto: {project_name} ({today})"]

    if active_skills:
        lines.append(f"[skill-finder] Skill già attive: {', '.join(active_skills)}")

    if not suggestions and not new_skills:
        if active_skills:
            lines.append("[skill-finder] Progetto già configurato. Nessuna nuova skill da suggerire.")
        else:
            lines.append("[skill-finder] Nessuna skill rilevante trovata per questo progetto.")
        return "\n".join(lines)

    if new_skills and active_skills:
        lines.append(f"\n[skill-finder] {len(new_skills)} skill nuove installate dall'ultima scansione:")
        for s in new_skills:
            lines.append(f"  - {s['name']}: {s['description'][:100]}")

    if suggestions:
        lines.append(f"\n[skill-finder] Suggerimenti ({len(suggestions)} skill rilevanti):")
        for s in suggestions:
            kw = ", ".join(s["keywords"])
            lines.append(f"  - {s['name']} (score: {s['score']}, match: {kw})")
            if s["description"]:
                lines.append(f"    → {s['description'][:120]}")

    lines.append(
        "\n[skill-finder:istruzioni] "
        "Presenta questi suggerimenti all'utente in modo conversazionale. "
        "Spiega PERCHÉ ogni skill è utile per QUESTO progetto specifico, "
        "basandoti sulle keyword che hanno matchato. "
        "Chiedi conferma prima di scrivere qualsiasi cosa nel CLAUDE.md. "
        "L'utente può approvare tutte, scegliere quali, o saltare."
    )

    return "\n".join(lines)


# ─── CLAUDE.md Writer ────────────────────────────────────────────────────────

def write_skills_to_claude_md(project_path: Path, approved_skills: list[str]) -> bool:
    """Write or update the skill-finder section in the project's CLAUDE.md."""
    content, md_path = read_claude_md(project_path)

    if md_path is None:
        md_path = project_path / "CLAUDE.md"

    today = date.today().isoformat()
    skills_str = ", ".join(approved_skills)
    trigger_lines = "\n".join(
        f"- **{s}** — Trigger: `/{s}`" for s in approved_skills
    )
    block = (
        f"{MARKER_START} {today}\n"
        f"## Skill attive (gestite da skill-finder — non modificare manualmente)\n"
        f"Skill attive: {skills_str}\n"
        f"\n"
        f"{trigger_lines}\n"
        f"\n"
        f"Quando l'utente digita uno di questi trigger, invoke the Skill tool con il nome corrispondente prima di fare altro.\n"
        f"{MARKER_END}"
    )

    if MARKER_START in content and MARKER_END in content:
        start = content.find(MARKER_START)
        end = content.find(MARKER_END) + len(MARKER_END)
        new_content = content[:start] + block + content[end:]
    elif content:
        new_content = content.rstrip() + "\n\n" + block + "\n"
    else:
        new_content = block + "\n"

    try:
        md_path.write_text(new_content, encoding="utf-8")
        return True
    except OSError:
        return False


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("[skill-finder] Errore: specificare il percorso del progetto.", file=sys.stderr)
        sys.exit(1)

    project_path = Path(sys.argv[1]).resolve()

    # --write mode
    if len(sys.argv) >= 4 and sys.argv[2] == "--write":
        approved = [s.strip() for s in sys.argv[3].split(",") if s.strip()]
        if not approved:
            print("[skill-finder] Errore: nessuna skill specificata.", file=sys.stderr)
            sys.exit(1)
        ok = write_skills_to_claude_md(project_path, approved)
        if ok:
            print(f"[skill-finder] OK — Skill scritte nel CLAUDE.md: {', '.join(approved)}")
        else:
            print("[skill-finder] ERRORE — Impossibile scrivere nel CLAUDE.md.", file=sys.stderr)
            sys.exit(1)
        return

    # Normal scan mode
    content, md_path = read_claude_md(project_path)
    installed = get_installed_skills()

    if not installed:
        print("[skill-finder] Nessuna skill installata trovata.")
        return

    active = get_active_skills(content)
    last_scan = get_last_scan_date(content)
    new_skills = has_new_skills_since(installed, last_scan)

    # Silent skip if already configured with no new skills
    if active and not new_skills and last_scan > 0:
        print("[skill-finder] Progetto già configurato. Nessuna nuova skill da suggerire.")
        return

    # Build full project context (CLAUDE.md + tech stack detection)
    project_context = get_project_context(project_path)

    # Filter candidates: exclude active and (for configured projects) only new
    active_set = set(active)
    candidates = [s for s in installed if s["name"] not in active_set and s["dir_name"] not in active_set]

    if active and new_skills:
        new_names = {s["name"] for s in new_skills} | {s["dir_name"] for s in new_skills}
        candidates = [s for s in candidates if s["name"] in new_names or s["dir_name"] in new_names]

    suggestions = score_skills(project_context, candidates)

    output = format_output(suggestions, new_skills, active, project_path)
    print(output)


if __name__ == "__main__":
    main()
