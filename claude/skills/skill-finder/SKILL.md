---
name: skill-finder
description: At the start of every session, automatically analyzes the project CLAUDE.md and suggests relevant installed skills from ~/.claude/skills/. Uses IDF-weighted dynamic matching — no hardcoded keyword maps. Proposes suggestions conversationally and writes approved skills to CLAUDE.md after user confirmation. Re-triggers when new skills are installed. Never imposes — always asks first.
auto-activate: true
trigger: /skill-finder
---

# Skill Finder

Analyzes project context and suggests the most relevant installed skills using dynamic IDF-weighted matching. Activates at session start via SessionStart hook.

---

## How scoring works

scan.py builds a keyword profile for each installed skill (from name, description, tags, and trigger phrases), then scores overlap against the project's CLAUDE.md and detected tech stack (package.json, etc.). Words appearing in few skills get higher weight (distinctive signals), words appearing in many skills get low or zero weight (too generic). No hardcoded keyword map — works with any set of skills.

---

## Cases

### Case 1 — New project (no skill-finder section in CLAUDE.md)

The SessionStart hook runs `scan.py` automatically and provides the output.
If the output contains `[skill-finder] Suggerimenti`, present the results as the **FIRST thing in the session**, before any other response.

Conversational format:
> "Ho analizzato il progetto **[project name]**. Tra le skill che hai installato, queste mi sembrano particolarmente utili qui:
>
> - **[skill-name]** — [specific reason for THIS project, based on matched keywords]
> - **[skill-name]** — [specific reason]
>
> Vuoi che le includa nel progetto? Puoi approvare tutte, scegliere quali, o saltare."

### Case 2 — Already configured, no new skills

If the output contains `Progetto già configurato` → **total silence**. Say nothing. Proceed normally with the user's request.

### Case 3 — Already configured, new skills installed

If the output contains `skill nuove installate`, report only the new skills:
> "Hai installato **[n] skill nuove** dall'ultima volta che ho analizzato questo progetto. **[name]** potrebbe essere utile qui perché [specific reason]. La aggiungo?"

### Case 4 — User approves

Run:
```bash
python3 ~/.claude/skills/skill-finder/scripts/scan.py "$CLAUDE_PROJECT_DIR" --write "skill1,skill2,skill3"
```
Where `skill1,skill2,skill3` are the approved skill names, comma-separated.

**CRITICAL — where to write:**
- ALWAYS write to the **project** CLAUDE.md via `scan.py --write` (it handles this automatically)
- NEVER manually edit `~/.claude/CLAUDE.md` (global) to add skill triggers — this would activate skills across ALL projects, defeating per-project scoping
- NEVER write trigger instructions to the global CLAUDE.md for skills suggested by skill-finder

Confirm: "Perfetto, ho aggiunto **[list]** al CLAUDE.md del progetto. Le userò quando pertinenti."

### Case 5 — User refuses

Reply: "Nessun problema." — Done. Don't insist. Don't re-suggest.

### Case 6 — Manual triggers

If the user says "rescan skills", "skill-finder update", or `/skill-finder`, force a new scan even on an already configured project:

```bash
python3 ~/.claude/skills/skill-finder/scripts/scan.py "$CLAUDE_PROJECT_DIR"
```

Present the output as in Case 1, including already active skills as context.

---

## Absolute rules

1. **Maximum 7 suggestions** — never more
2. **Always explain WHY** each skill is relevant for THAT specific project, not in the abstract. Use the matched keywords from scan.py output to build the reason
3. **Human, direct tone** — conversational, not technical. Don't show scores or raw keywords to the user
4. **Never run scan.py twice** in the same session (the hook already runs it once)
5. **Never modify CLAUDE.md without explicit user confirmation**
6. **Don't interpret "yes" as "yes to all"** — if the user doesn't specify, ask which skills they want among those suggested
7. **If the hook output is empty or silent** → do nothing, proceed normally
