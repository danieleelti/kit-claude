# Kit Claude — note per Claude

- Cartella `/opt/app/workspace/claudecodeui/srv/kit-claude` (= `/root/claudecodeui/srv/kit-claude`): dentro il backup Elestio. Repo privato `danieleelti/kit-claude`.
- Valgono le regole globali di `/root/.claude/CLAUDE.md` (regola aurea: commit + push frequenti, segreti e DB nel vault, mai solo sul server).
- Se nasce un servizio: porta locale libera, vhost nginx in `/opt/elestio/nginx/conf.d/`, processo pm2 con `env -u PORT -u NODE_ENV`, poi `pm2 save`.
- Flusso (regola globale): ideazione, spec e piano con **Fable**; esecuzione del piano con **Opus**. Spec in `docs/superpowers/specs/`, piano in `docs/superpowers/plans/`.

## Da dove ripartire
- Progetto appena creato: nessuna spec ancora. Prossimo passo: sessione Fable per capire l'idea e scrivere spec e piano.
