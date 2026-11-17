# Kit Claude

Lo stack Claude Code di Daniele (TeamBuilding.it) impacchettato per essere replicato su un altro server: skill, agenti,
comandi gsd, hook, modelli di CLAUDE.md e settings, script di installazione (strumenti, CloudCLI con pm2, nginx, GitHub,
vault dei segreti). Nato il 17/11/2026 per il server di un amico di Daniele, a partire dalla sandbox di Francesca
(repo `francesca`), ma per un utente che è padrone del proprio server.

**Punto d'ingresso per il Claude dell'altro server: [ISTRUZIONI-PER-CLAUDE.md](ISTRUZIONI-PER-CLAUDE.md).**

- `claude/` è generato da `costruisci-kit.sh` sul server di Daniele (segnaposto `__HOME__`, `__CLAUDE_DIR__`, `__NODE_BIN__`, `__NOME__`); `claude/ELENCO.md` elenca le skill.
- `modelli/`, `scripts/`, `nginx/`: modelli e script parametrizzati da `kit.env` (copia di `kit.env.esempio`).
- Repo privato `danieleelti/kit-claude`, cartella `/root/claudecodeui/srv/kit-claude` (backup Elestio). Nessun segreto dentro: `costruisci-kit.sh` si ferma se ne trova uno.
