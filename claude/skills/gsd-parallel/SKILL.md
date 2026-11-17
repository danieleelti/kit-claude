---
name: gsd-parallel
description: Execute a GSD phase with parallel subagents on isolated git worktrees. Use when a phase has 4+ independent plans with no file conflicts between them.
user-invokable: true
argument-hint: "phase-N"
---

# Skill: gsd-parallel
# Invocazione: /gsd-parallel phase-N
# Scopo: eseguire una fase GSD con subagents paralleli su git worktrees separati

## Quando usare
Quando una fase GSD ha 4+ piani indipendenti (nessuna dipendenza di file tra loro).
Non usare se i piani toccano gli stessi file — eseguirli in sequenza è più sicuro.

## Procedura

### Fase 1 — Analisi dipendenze
1. Leggi tutti i piani in `./gsd/phase-N/`
2. Per ogni piano, elenca i file che intende toccare
3. Costruisci una matrice di conflitti: quali piani toccano gli stessi file?
4. Dividi in gruppi: paralleli (nessun conflitto) e sequenziali (conflitti)
5. Mostra la matrice e aspetta conferma ("vai") prima di procedere

### Fase 2 — Esecuzione parallela
Per ogni gruppo parallelo:
1. Crea un git worktree isolato: `git worktree add ../worktree-plan-N -b plan-N`
2. Spawna un Task subagent per ogni piano con queste istruzioni:
   - Lavora solo nella tua worktree
   - Implementa il piano
   - Esegui `tsc --noEmit` e correggi eventuali errori
   - Esegui i test in `tests/regressions/` se esistono
   - Committa con messaggio descrittivo
   - Riporta: ✅ completato | ❌ fallito: [motivo]
3. Aspetta che tutti i subagents completino

### Fase 3 — Merge e verifica
1. Per ogni worktree completato con successo:
   - `git merge plan-N --no-ff`
   - Risolvi conflitti se presenti
   - Esegui `tsc --noEmit` sul merge
2. Esegui i piani sequenziali uno alla volta
3. Pulisci le worktree: `git worktree remove ../worktree-plan-N`

### Report finale
```
=== GSD PARALLEL PHASE N ===
Piani totali: N
Eseguiti in parallelo: N
Eseguiti in sequenza: N
Successi: N
Falliti: N (lista)
```

## Note
- Se git worktree non è disponibile, esegui tutti i piani in sequenza
- Non usare questa skill su progetti senza git inizializzato
- I subagents non hanno accesso al contesto della sessione principale:
  includi nel loro prompt tutto il necessario (path, stack, convenzioni)
