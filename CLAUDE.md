# Kit Claude — note per Claude (lato Daniele)

- Cartella `/opt/app/workspace/claudecodeui/srv/kit-claude` (= `/root/claudecodeui/srv/kit-claude`): dentro il backup Elestio. Repo privato `danieleelti/kit-claude`, branch `main`.
- Valgono le regole globali di `/root/.claude/CLAUDE.md` (regola aurea: commit + push frequenti; qui non ci sono segreti e non devono entrarci).
- Cos'è: il pacchetto per replicare lo stack di Daniele (skill, hook, CLAUDE.md, settings, CloudCLI, nginx, vault) sul server di un'altra persona, con il suo GitHub, dominio e abbonamento. Creato il 17/11/2026 (Fable) per il server di un amico di Daniele. Il documento per il Claude dell'altro server è `ISTRUZIONI-PER-CLAUDE.md`; il resto del repo è ciò che quel documento cita.
- Deriva dalla sandbox di Francesca (`/root/claudecodeui/srv/francesca`: spec, piano, modelli e script), ma senza isolamento: l'utente è padrone del suo server.

## Come si aggiorna
- Quando Daniele cambia skill, hook o agenti: `./costruisci-kit.sh` (rigenera `claude/` da `/root/.claude` con i segnaposto e controlla che non ci siano segreti), poi commit + push. L'altro Claude fa `git pull` + `scripts/installa-kit.sh`.
- Quando cambiano le versioni (Node, Claude Code, CloudCLI, pm2): aggiornare `kit.env.esempio` e la tabella in `ISTRUZIONI-PER-CLAUDE.md` §2.
- Quando cambia una regola nel CLAUDE.md globale di Daniele o in quello di Francesca: riportarla in `modelli/CLAUDE-globale.md` (segnaposto `__NOME__`, `__DOMINIO__`, `__GITHUB_USER__`, `__SRV__`, `__HOME__`, `__KIT_DIR__`, `__CLAUDE_DIR__`, `__PORTA_*__`, `__DATA__`; blocchi `<!-- principiante -->` / `<!-- esperto -->`).
- Gli script di `scripts/` sono generici (leggono `kit.env`); provati qui solo a secco (`installa-kit.sh` in una home finta, `nuovo-progetto.sh --senza-github`, `sync-vault.sh --prova`, `controllo-backup.sh`): sul server dell'amico li collauda il suo Claude.

## Come si consegna
- Daniele sceglie: zip del repo (GitHub → Code → Download ZIP) caricato sul server dell'amico; oppure amico collaboratore del repo privato; oppure repo pubblico (non contiene segreti né dati di Daniele, solo skill di terzi open source e modelli con segnaposto).
- All'altro Claude basta `ISTRUZIONI-PER-CLAUDE.md`: §1 domande all'utente, §4 installazione in ordine, §4.9 collaudo.

## Da dove ripartire
- 17/11/2026: kit costruito e documentato; nessun collaudo su un server reale ancora. Primo feedback atteso dal Claude dell'amico (cosa non ha funzionato dei suoi script) → correggere qui e ripushare.
