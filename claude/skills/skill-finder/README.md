# skill-finder

> Automatically suggests relevant Claude Code skills for each project. Zero configuration, fully dynamic.

## The Problem

You have dozens of Claude Code skills installed, but you don't remember which ones exist or which are relevant for the project you're working on. You end up either not using skills at all, or manually browsing through `~/.claude/skills/` every time you start a new project.

## The Solution

**skill-finder** runs at the start of every Claude Code session. It reads your project's `CLAUDE.md`, detects your tech stack, cross-references everything with all installed skills, and suggests the most relevant ones — conversationally, before you even ask.

After you approve, it writes your choices to the project's `CLAUDE.md` so Claude knows which skills to use going forward. Next session: silence. It only speaks when there's something new to say.

## How It Works

### Conversational Flow

**New project (first time):**
```
Claude: Ho analizzato il progetto "my-saas-app". Tra le skill installate,
        queste mi sembrano particolarmente utili qui:

        - react-best-practices — the project uses React and Next.js
        - seo — SEO is mentioned as a priority in CLAUDE.md
        - design-taste-frontend — custom UI with Tailwind CSS

        Want me to include them? You can approve all, pick some, or skip.

You:    Yes, all of them.

Claude: Done. Added react-best-practices, seo, design-taste-frontend
        to CLAUDE.md. I'll use them when relevant.
```

**Already configured, no new skills:**
```
(silence — Claude proceeds normally)
```

**New skills installed since last scan:**
```
Claude: You've installed 2 new skills since last time. "shadcn-ui" might
        be useful here because the project uses shadcn components. Add it?
```

### Scoring Algorithm: IDF-Weighted Dynamic Matching

No hardcoded keyword maps. The scoring is fully dynamic and works with **any** set of installed skills:

1. **Profile building** — For each installed skill, extracts keywords from:
   - Skill name (split on hyphens)
   - Description text
   - Tags (when present in frontmatter)
   - Trigger phrases from body ("Use when...", "Activate when...", etc.)

2. **Project context** — Builds a keyword profile from:
   - Your project's `CLAUDE.md`
   - Tech stack detection: `package.json` dependencies, `tsconfig.json`, `next.config.*`, `tailwind.config.*`, `requirements.txt`, `Dockerfile`, and 20+ other project files

3. **IDF scoring** — For each overlapping keyword between skill and project:
   - Words in **≤5%** of skills → weight **3** (very distinctive)
   - Words in **≤15%** of skills → weight **2** (uncommon)
   - Words in **≤30%** of skills → weight **1** (moderate)
   - Words in **>30%** of skills → weight **0** (too generic, skip)

4. **Direct name bonus** — If a skill's name appears in your `CLAUDE.md` (e.g., "SEO" → `seo` skill), it gets **+5 points**

5. **Filtering** — Results filtered to `MIN_SCORE ≥ 5`, capped at 7 suggestions, excluding already-active skills

### Why IDF?

A keyword like "react" appearing in 4 out of 65 skills is a strong signal — it means the skill is specifically about React. A keyword like "design" appearing in 28 out of 65 skills is noise — almost half the skills mention it. IDF automatically learns this from your installed skills, no configuration needed.

## Installation

```bash
# Clone to your skills directory
git clone https://github.com/user/skill-finder.git ~/.claude/skills/skill-finder

# Install the SessionStart hook
python3 ~/.claude/skills/skill-finder/install.py
```

That's it. Next time you open a project, skill-finder activates automatically.

### Manual Triggers

Trigger a rescan anytime:
- Say `rescan skills` or `skill-finder update` to Claude
- Use `/skill-finder`

## File Structure

```
~/.claude/skills/skill-finder/
├── SKILL.md              # Instructions for Claude (behavioral rules)
├── install.py            # One-time hook installer (idempotent)
├── README.md             # This file
└── scripts/
    ├── scan.py           # Core scanning and scoring engine
    └── session_hook.py   # SessionStart hook wrapper (fail-silent)
```

## Requirements

- Python 3.10+
- Claude Code with skills support
- Skills installed in `~/.claude/skills/` with `SKILL.md` files containing frontmatter (`name` and `description` fields)

## What Gets Written to CLAUDE.md

After approval, skill-finder adds this block:

```markdown
<!-- skill-finder:start --> 2026-04-13
## Skill attive
<!-- Gestito da skill-finder — non modificare manualmente -->
Skill attive: react-best-practices, design-taste-frontend, seo
Quando lavori su questo progetto, usa queste skill quando pertinenti.
<!-- skill-finder:end -->
```

The block is managed by markers — skill-finder updates it in place on re-scans.

## Tuning

In `scripts/scan.py`:

| Constant | Default | Description |
|----------|---------|-------------|
| `MIN_SCORE` | 5 | Minimum IDF score to suggest a skill |
| `MAX_SUGGESTIONS` | 7 | Maximum skills to suggest per scan |
| `DIRECT_NAME_BONUS` | 5 | Bonus when skill name appears in project |

### Short Signals

Technical acronyms like `seo`, `ui`, `ux`, `api`, `css`, `pwa`, `ssr` (2-3 chars) are handled via a curated `SHORT_SIGNALS` set that bypasses the minimum word length filter.

## Design Decisions

- **No hardcoded keyword maps** — Works with any skills, no maintenance needed when you install or remove skills
- **Trigger phrase extraction** — Only reads "Use when...", "Activate when..." lines from skill bodies, not the entire text (avoids noise from instructional content)
- **Tech stack detection** — Reads `package.json`, `requirements.txt`, config files, etc. so even a minimal `CLAUDE.md` produces good results
- **Fail-silent hook** — `session_hook.py` catches all exceptions and exits cleanly. Never blocks session startup
- **Idempotent installer** — `install.py` is safe to run multiple times. Detects existing hooks

## Contributing

PRs welcome. Key areas:

- Add entries to `SHORT_SIGNALS` for domain-specific acronyms
- Add entries to `TECH_STACK_FILES` for language/framework detection
- Improve `extract_trigger_phrases` to catch more skill body patterns
- Add tests

## License

MIT
