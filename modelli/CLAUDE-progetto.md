# __VISTA__ — note per Claude

- Cartella `__CARTELLA__`. Repo privato GitHub `__GITHUB_USER__/__PROGETTO__`, branch `main`.
- Valgono le regole globali di `__CLAUDE_DIR__/CLAUDE.md` (regola aurea: commit + push frequenti, segreti e DB nel vault, mai solo sul server).
- Se nasce un servizio: porta locale libera legata a 127.0.0.1, prova su https://__DOMINIO__/anteprima/ (porta __PORTA_ANTEPRIMA__); per metterlo online: vhost nginx, processo pm2 avviato con `env -u PORT -u NODE_ENV pm2 start …`, poi `pm2 save`.
- Flusso (regola globale): ideazione, spec e piano con **Fable**; esecuzione del piano con subagenti **Opus**. Spec in `docs/superpowers/specs/<data>-<tema>-design.md`, piano in `docs/superpowers/plans/<data>-<tema>.md`.

## Da dove ripartire
- Progetto creato il __DATA__: nessuna spec ancora. Prossimo passo: sessione Fable per capire l'idea (superpowers:brainstorming) e scrivere spec e piano.
