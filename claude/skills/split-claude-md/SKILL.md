# Skill: split-claude-md
# Invocazione: /split-claude-md
# Scopo: dividere un CLAUDE.md monolitico in file separati per ridurre il contesto

## Quando usare questa skill
Quando un file CLAUDE.md supera ~300 righe o contiene sezioni logicamente distinte
(architettura, deploy, workflow, convenzioni, API, ecc.)

## Procedura

1. **Analisi**: leggi l'intero CLAUDE.md e identifica le sezioni logiche presenti.
   Non usare una struttura fissa — adatta la divisione ai contenuti reali del file.

2. **Proposta**: prima di creare qualsiasi file, elenca:
   - I nomi dei file che intendi creare (es. docs/claude/architettura.md)
   - Le sezioni che finiscono in ciascun file
   - La struttura dell'indice principale
   Aspetta conferma ("vai") prima di procedere.

3. **Esecuzione**:
   - Crea la cartella docs/claude/ nella root del progetto (se non esiste)
   - Crea ogni file con il contenuto appropriato
   - Riscrivi CLAUDE.md come indice di ~50 righe con riferimenti ai file creati
     usando la sintassi: @docs/claude/nomefile.md

4. **Verifica**: rileggi l'indice CLAUDE.md e conferma che tutti i riferimenti
   puntino a file esistenti.

5. **Report finale**: elenca i file creati con il numero di righe ciascuno.

## Note
- Preserva tutto il contenuto originale, non eliminare nulla
- Se il CLAUDE.md è già un indice con @riferimenti, di' all'utente che non serve splittare
- I nomi dei file devono essere in italiano o inglese coerentemente col progetto
