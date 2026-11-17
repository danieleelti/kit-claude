# Istruzioni per Claude — replicare lo stack di Daniele su un altro server

Scritto il 17/11/2026 da Claude (Fable 5.1) sul server di Daniele (TeamBuilding.it), per il Claude che gira sul server di
un suo amico. Daniele vuole dare all'amico **lo stesso stack, le stesse skill e le stesse istruzioni** che ha preparato il
13/11/2026 per la sua collega Francesca (francesca.teambuilding.it), con una differenza: qui l'utente è **il padrone del
suo server e della sua roba**, non un ospite in sandbox. Quindi niente isolamento da altri utenti, niente «fase 2»,
niente chiavi di Daniele: GitHub, dominio, abbonamento Claude e segreti sono dell'utente.

Questo file è la tua guida: leggilo tutto una volta, poi segui l'ordine della §4. Nelle sezioni trovi i «perché»: non
sono decorazione, sono le lezioni imparate sul server di Daniele (un server cancellato il 06/11/2026 con tutto quello che
non era su GitHub, una falla di /proc che mostrava chiavi API, pm2 che ereditava la porta sbagliata…).

---

## 1. Prima di cominciare: cosa chiedere all'utente

Fai una domanda alla volta, con opzioni (A/B/C) dove ha senso. Le risposte finiscono in `kit.env` (vedi §3).

1. **Come ti chiami e come preferisci che ti parli?** (nome → `NOME`; tono → `LIVELLO`: `principiante` se non ha mai
   programmato e non conosce terminale/git, `esperto` se sì). Con un principiante il CLAUDE.md ti mette in modalità
   **tutor**: una cosa alla volta, spiegare ogni termine, chiedere «vai» prima di fare cose grandi.
2. **Che account GitHub hai?** (`GITHUB_USER`). Se non lo ha: lo crea su https://github.com/signup con la sua email, poi
   `gh auth login` dal terminale (GitHub.com → HTTPS → «Login with a web browser»). Spiega che tutto il lavoro finirà in
   repository **privati** suoi: è la regola aurea (§5).
3. **Che dominio useremo per la Claude Code UI nel browser?** (`DOMINIO`, es. `claude.suodominio.it`). Serve un record
   DNS A verso l'IP del server, lo fa lui dal pannello del suo provider DNS. Finché non c'è, si può lavorare da terminale.
4. **Che abbonamento Claude hai?** Max o Pro → login con `/login` dalla chat di CloudCLI (OAuth nel browser). Solo API →
   `ANTHROPIC_API_KEY` in `.env.cloudcli`. Un token lungo (`claude setup-token`, dura 1 anno) è la terza via.
5. **Il server**: distribuzione (Ubuntu/Debian?), sei root o un utente con sudo?, c'è già nginx o un altro reverse proxy
   (Elestio? Caddy? Traefik?), c'è docker?, quali porte sono già occupate (`ss -ltnp`). Decidi con lui l'utente Linux che
   farà girare tutto (`HOME_UTENTE`): su un server personale di solito è root; se preferisce un utente dedicato, va bene,
   ma allora pm2 e cron sono di quell'utente.
6. **Vuoi la modalità caveman?** (risposte ultra-brevi, `CAVEMAN=si|no`). Con un principiante: no, è in contrasto con il
   ruolo di tutor.
7. **Confermi la regola aurea?** Leggigli la §5 in due frasi (ogni progetto = repo GitHub privato; segreti e database in un
   secondo repo privato `secrets-vault`, aggiornato ogni ora da uno script) e chiedi «vai». Quel «vai» è l'autorizzazione
   permanente che il CLAUDE.md cita: da lì in poi creare repo privati e pushare sono backup, non si chiede più.

---

## 2. Lo stack (versioni al 17/11/2026, fisse: niente aggiornamenti automatici)

| Pezzo | Versione | A cosa serve | Note |
|---|---|---|---|
| Node.js via nvm | 22.23.4 (nvm v0.40.3) | runtime di CloudCLI, pm2, hook, app | nella home dell'utente, non quello di sistema |
| Claude Code (installer nativo) | 2.1.319 | la CLI vera e propria | `curl -fsSL https://claude.ai/install.sh \| bash -s 2.1.319` → `~/.local/bin/claude`; `DISABLE_AUTOUPDATER=1` |
| CloudCLI (`@cloudcli-ai/cloudcli`) | 1.37.7 | Claude Code nel browser: chat, terminale, file, selettore del modello | `npm i -g`; **ascolta solo su 127.0.0.1**, la espone nginx |
| pm2 | 6.0.14 | tiene su CloudCLI e le app dell'utente | `pm2 save` dopo ogni modifica; `pm2 startup` una volta |
| nginx + Let's Encrypt | quello del server | https sul dominio, websocket, `/anteprima/` con password | modelli in `nginx/` |
| gh (GitHub CLI) | ultima | repo privati, push | login OAuth nel browser |
| Python 3, sqlite3, git, rsync, openssl | di sistema | hook skill-finder, dump dei DB per il vault, htpasswd | `apt install` |
| uv (facoltativo) | ultima | Python moderno per hyperresearch e qualche skill | `installa-strumenti.sh --con-uv` |
| MCP `context7` | npx `@upstash/context7-mcp` | documentazione aggiornata di librerie | nessuna chiave |
| MCP `playwright` | npx `@playwright/mcp@latest --no-sandbox` | browser per prove e screenshot | serve Chromium: `npx playwright install --with-deps chromium` (root per le dipendenze) |
| Plugin `superpowers` | 6.2.0 (`claude-plugins-official`) | **il metodo di lavoro**: brainstorming → spec → piano → esecuzione con subagenti, TDD, debugging sistematico | obbligatorio |
| Plugin `frontend-design` | `claude-plugins-official` | design di interfacce non «da template» | |
| Plugin `ui-ux-pro-max` | 2.5.0 (`nextlevelbuilder/ui-ux-pro-max-skill`) | regole UI/UX | |
| Plugin `pg` | 0.4.0 (`timescale/pg-aiguide`) | Postgres/Timescale con MCP di documentazione | |
| get-shit-done (GSD) | 1.30.0 | comandi `/gsd:*`, agenti `gsd-*`, hook di contesto e statusline | nel kit; in alternativa `npx get-shit-done-cc@latest` |
| Skill in `~/.claude/skills` | 109 cartelle | vedi §6 e `claude/ELENCO.md` | nel kit |
| Hook di Daniele | `context-alert.js`, `fix-mcp-auth-cache.js` | avvisi a 650k/850k token e file di ripresa; pulizia cache MCP | nel kit, con i percorsi riscritti |

Cosa dello stack di Daniele **non** c'è nel kit, di proposito, perché legato ai suoi account: MCP Supabase, Stripe,
Firecrawl, Stitch, Instagram, Meta Ads, Gmail/Drive/Calendar/Docs (connettori claude.ai), n8n; le skill `instagram-skills`
e `linkedin-skills`; le skill `synced` di claude.ai (si sincronizzano da sole con l'account dell'utente). Se l'utente ha i
suoi account di questi servizi, si aggiungono con `claude mcp add` e le sue chiavi.

---

## 3. Il kit: dove sta e com'è fatto

Il kit è il repository **pubblico** https://github.com/danieleelti/kit-claude (nessun segreto dentro: skill di terzi,
modelli con segnaposto, script). Clonalo in `KIT_DIR` (consiglio: `$HOME/kit-claude`):
```bash
git clone https://github.com/danieleelti/kit-claude.git $HOME/kit-claude
```
Per aggiornarlo in futuro: `git pull` nella stessa cartella. Se per qualche motivo non puoi clonarlo, vai alla §8.

```
kit-claude/
├── ISTRUZIONI-PER-CLAUDE.md   ← questo file
├── kit.env.esempio            ← parametri: copia in kit.env e compila (NOME, GITHUB_USER, DOMINIO, HOME_UTENTE, porte…)
├── costruisci-kit.sh          ← (lato Daniele) rigenera claude/ dal suo server; a te non serve
├── claude/                    ← skills/ agents/ commands/ get-shit-done/ hooks/ + manifest, con segnaposto __HOME__ ecc.
│   └── ELENCO.md              ← elenco delle skill con l'origine
├── modelli/
│   ├── CLAUDE-globale.md      ← il CLAUDE.md globale dell'utente (blocchi principiante/esperto, segnaposto)
│   ├── settings.json          ← permessi, hook, statusline, plugin, marketplace, autoMode
│   ├── CLAUDE-progetto.md     ← CLAUDE.md di ogni progetto nuovo (lo usa nuovo-progetto.sh)
│   └── benvenuto-README.md    ← README del primo progetto «Benvenuto»
├── scripts/
│   ├── _comune.sh             ← legge kit.env (lo usano tutti gli script)
│   ├── installa-strumenti.sh  ← nvm, Node, Claude Code, CloudCLI, pm2, gh (+uv)
│   ├── installa-kit.sh        ← skill/hook/agenti/gsd in ~/.claude, --modelli per CLAUDE.md e settings, MCP, plugin
│   ├── avvia-cloudcli.sh + cloudcli.config.cjs ← CloudCLI con pm2; --registra crea il primo utente
│   ├── nuovo-progetto.sh      ← cartella + README/.gitignore/CLAUDE.md + repo privato + push + riga in CloudCLI
│   ├── sync-vault.sh          ← segreti e dump SQLite → repo privato <GITHUB_USER>/secrets-vault (cron ogni ora)
│   └── controllo-backup.sh    ← cosa non è ancora al sicuro fuori dal server
└── nginx/
    ├── cloudcli.conf.esempio          ← nginx di sistema + certbot
    └── cloudcli-elestio.conf.esempio  ← variante per un server Elestio (OpenResty, auto-ssl, ALLOWED_DOMAINS)
```

Tutti gli script leggono `kit.env` (o il file indicato in `KIT_ENV=`), sono idempotenti e si rilanciano senza danni.
Leggili prima di lanciarli: sono corti e commentati, e il server dell'utente può avere differenze che io non conosco.

---

## 4. Installazione, nell'ordine

Lavora come l'utente Linux scelto (`HOME_UTENTE`). Dopo ogni passo di' all'utente cosa è successo, in una riga.

### 4.1 Parametri
```bash
cd $HOME/kit-claude && cp kit.env.esempio kit.env && nano kit.env    # o scrivilo tu con i valori raccolti in §1
```

### 4.2 Strumenti
```bash
scripts/installa-strumenti.sh            # --con-uv se vuole hyperresearch/Python moderno
```
Verifica: `node -v` → v22.23.4, `claude --version` → 2.1.319, `cloudcli --version` → 1.37.7, `pm2 -v` → 6.0.14,
`gh --version`. Se la shell non vede i comandi: `source ~/.profile` (il blocco `# >>> kit-claude >>>` mette nvm e
`~/.local/bin` nel PATH anche per le shell non interattive: pm2, cron, `bash -lc`).

### 4.3 Configurazione Claude (skill, hook, CLAUDE.md, settings, MCP, plugin)
```bash
scripts/installa-kit.sh --modelli
```
Fa: `claude/` → `~/.claude` con i segnaposto sostituiti; `CLAUDE.md` e `settings.json` dai modelli (il blocco del livello
scelto; copia di sicurezza dei file precedenti con suffisso `.prima-del-kit-*`); MCP context7 e playwright (scope user);
marketplace e 4 plugin; prova che ogni hook parta. Se un plugin non si installa (rete, marketplace cambiato) lo dice:
riprova con `claude plugin install <nome>@<marketplace>` o con `/plugin` dalla chat.
Poi: `npx playwright install --with-deps chromium` (le dipendenze di sistema vogliono root/sudo).

Controlla il risultato aprendo una sessione `claude` in una cartella qualsiasi: nel system prompt devono comparire le
skill (`superpowers:brainstorming`, `impeccable`, `skill-finder`…), la statusline GSD, nessun errore di hook.

### 4.4 CloudCLI con pm2
```bash
scripts/avvia-cloudcli.sh                # prima volta: crea scripts/.env.cloudcli (JWT_SECRET generato), avvia, pm2 save
nano scripts/.env.cloudcli               # CLOUDCLI_USER e CLOUDCLI_PASSWORD scelti dall'utente (mai in chat); eventuale ANTHROPIC_API_KEY
scripts/avvia-cloudcli.sh --registra     # primo utente; dopo di lui CloudCLI chiude le iscrizioni da sé (403 AUTH_USER_ALREADY_CONFIGURED)
```
`.env.cloudcli` contiene `HOST=127.0.0.1` (**obbligatorio**: il default di CloudCLI è 0.0.0.0, cioè esposta su internet
senza password di nginx), `SERVER_PORT`, `DATABASE_PATH`, `CLAUDE_CLI_PATH`, `CLAUDE_CONFIG_DIR`, `DISABLE_AUTOUPDATER`.
Verifica: `ss -ltnp | grep <porta>` mostra solo 127.0.0.1; `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:<porta>/`
→ 200. Riavvio automatico al boot: il comando che stampa `pm2 startup` (una volta, da root).

### 4.5 nginx, DNS e https
- DNS: record A `DOMINIO` → IP del server (lo fa l'utente; `dig +short DOMINIO` per controllare).
- **Server normale** (nginx di sistema): `nginx/cloudcli.conf.esempio` → `/etc/nginx/sites-available/cloudcli.conf`
  con i segnaposto sostituiti (`sed "s#__DOMINIO__#…#; s#__PORTA_CLOUDCLI__#…#; s#__PORTA_ANTEPRIMA__#…#"`), link in
  `sites-enabled`, `nginx -t && systemctl reload nginx`, poi `certbot --nginx -d DOMINIO` (apt `certbot
  python3-certbot-nginx`). Firewall: 80 e 443 aperte, la porta di CloudCLI **no**.
- **Server Elestio**: `nginx/cloudcli-elestio.conf.esempio` → `/opt/elestio/nginx/conf.d/DOMINIO.conf`; dominio nella
  regex `ALLOWED_DOMAINS` di `/opt/elestio/nginx/.env` (forma `nome[.]dominio[.]it`); `docker exec elestio-nginx nginx -t`;
  `cd /opt/elestio/nginx && docker compose up -d` (un `docker restart` non rilegge l'env). Il certificato arriva al primo
  accesso https.
- Password dell'anteprima: `printf '%s:%s\n' UTENTE "$(openssl passwd -apr1)" > <percorso>/anteprima.htpasswd`
  (stesso utente/password di CloudCLI, se l'utente vuole; leggibile dall'utente di nginx).
- Verifica dal browser: `https://DOMINIO/` → login di CloudCLI; `https://DOMINIO/anteprima/` → chiede la password.

### 4.6 Login a Claude e primo progetto
- Dalla chat di CloudCLI: `/login` (Max/Pro) → URL da aprire nel browser → codice da incollare. Con la sola API:
  `ANTHROPIC_API_KEY` in `.env.cloudcli` e `scripts/avvia-cloudcli.sh`.
- Al primo accesso CloudCLI chiede nome ed email per git (`git config --global`): quelli del suo GitHub. Se li salti,
  impostali tu: `git config --global user.name "<nome>"; git config --global user.email "<email del GitHub>"` (senza
  identità `git commit` si rifiuta; `nuovo-progetto.sh` ripiega su `<GITHUB_USER>@users.noreply.github.com` per il solo repo).
- `gh auth login` dal terminale di CloudCLI (tab Terminal; il tab «Shell» apre la CLI di Claude, non bash: i comandi si
  danno con `!`).
- Primo progetto: `scripts/nuovo-progetto.sh benvenuto Benvenuto`, poi `modelli/benvenuto-README.md` (segnaposto
  sostituiti) come `README.md` del progetto. Ricarica CloudCLI: «Benvenuto» è in elenco.

### 4.7 Backup (regola aurea) e cron
```bash
scripts/sync-vault.sh --prova            # mostra cosa finirebbe nel vault, senza git
scripts/sync-vault.sh                    # crea <GITHUB_USER>/secrets-vault (privato) e pusha
scripts/controllo-backup.sh              # atteso: OK
( crontab -l 2>/dev/null; echo "7 * * * * $HOME/kit-claude/scripts/sync-vault.sh >> $HOME/sync-vault.log 2>&1" ) | crontab -
touch $HOME/SECRETS-BACKUP.md && chmod 600 $HOME/SECRETS-BACKUP.md   # qui si annotano i segreti non rigenerabili (nomi, dove stanno, scadenze)
```
Il vault prende: `.env*` reali dei progetti, `*credentials*.json`, `*service-account*.json`, `SECRETS*.md`, cartelle
`secrets/`, dump di ogni SQLite, `.env.cloudcli`, `kit.env`, crontab, pm2 dump, vhost nginx, configurazione di Claude
(CLAUDE.md, settings, hook, skill, memoria, server MCP con le chiavi). Un segreto con un altro nome **non** viene preso:
aggiungi il pattern allo script e dillo all'utente.

### 4.8 Chiudere il CLAUDE.md
Compila la sezione **«Ambiente di questo server»** in fondo a `~/.claude/CLAUDE.md` con quello che hai trovato davvero
(sistema, proxy, porte, backup del provider, servizi esterni dell'utente). È la mappa che userai nelle prossime sessioni.
Il kit clonato resta collegato al repo pubblico di Daniele per i `git pull`: lì non c'è nulla da committare, i parametri
dell'utente stanno in `kit.env` e `.env.cloudcli`, fuori da git e dentro il vault (ci pensa `sync-vault.sh`).

### 4.9 Collaudo finale (tutti verdi prima di dire «fatto»)
1. Versioni: node, claude, cloudcli, pm2, gh come in §2.
2. `pm2 ls` → `cloudcli` online; porta solo su 127.0.0.1; `pm2 startup` fatto.
3. Browser: login su `https://DOMINIO/`, progetto «Benvenuto» in elenco, una chat risponde (dopo `/login`), il terminale
   apre una shell dell'utente giusto (`whoami`).
4. `/anteprima/`: 401 senza password; con `python3 -m http.server <PORTA_ANTEPRIMA> --bind 127.0.0.1` nel progetto → 200.
5. In una sessione Claude: la statusline c'è, `/skill-finder` risponde, `/gsd:help` risponde, la skill
   `superpowers:brainstorming` è in elenco, nessun errore di hook all'avvio.
6. `gh auth status` ok; `nuovo-progetto.sh` ha creato il repo privato; `sync-vault.sh` ha pushato; `controllo-backup.sh`
   → OK; la riga di cron c'è.
7. `~/.claude/CLAUDE.md` ha la sezione «Ambiente di questo server» compilata.

---

## 5. Le regole di lavoro (il perché del CLAUDE.md)

Il `CLAUDE.md` globale (`modelli/CLAUDE-globale.md`) è l'adattamento di quello di Francesca più le regole globali di
Daniele. Le sue parti, e la storia che le motiva:
- **Regola aurea: niente vive solo sul server.** Il 06/11/2026 il server di Daniele è stato cancellato e si è salvato
  solo ciò che era su GitHub. Da allora: ogni progetto è un repo privato con push frequenti; segreti e DB in
  `secrets-vault` ogni ora; checklist a fine lavoro (commit+push, sync-vault, SECRETS-BACKUP.md, controllo-backup.sh);
  un push bloccato si dice subito. Salvare non vuol dire stampare: i valori dei segreti restano fuori da chat e log.
- **Si progetta con Fable, si esegue con Opus.** Fable 5.1 per capire, specificare, pianificare; Opus per implementare.
  Fable lancia da solo subagenti Opus (`superpowers:subagent-driven-development`), uno per task del piano, e fa la regia.
  Deroga solo esplicita dell'utente.
- **«vai»** è l'unica parola di conferma. Prima di toccare più file o di cancellare: elenco + «vai».
- **Due elenchi a fine messaggio**: «Da fare <NOME>» e «Da fare Claude», «niente» se vuoti. È il modo in cui l'utente
  sa sempre cosa tocca a lui (pannelli, chiavi, DNS, prove dal browser).
- **Tutor con un principiante**: una cosa alla volta, ogni termine spiegato, mostrare il risultato, niente codice in
  chat se non serve. Con un esperto il blocco è un paragrafo.
- **Mai localhost nei link per le persone**; redirect da `NEXT_PUBLIC_APP_URL`, non da `req.url` (bug del 06/11/2026 su
  un'app di Daniele dietro nginx).
- **pm2 con `env -u PORT -u NODE_ENV`** e `pm2 save`: altrimenti le app ereditano la porta di CloudCLI.
- **Finestra di contesto**: `context-alert.js` avvisa a 650k e 850k token e scrive il file di ripresa; la sessione nuova
  nella stessa cartella lo propone da sola.
- **Mai attivare automazioni senza conferma**; mai toccare settings e hook senza dirlo.

---

## 6. Le skill: cosa c'è, da dove viene, cosa serve a ognuna

`claude/ELENCO.md` ha la tabella completa (109 cartelle). Per famiglie:
- **superpowers** (plugin, 6.2.0): brainstorming, writing-plans, executing-plans, subagent-driven-development,
  test-driven-development, systematic-debugging, verification-before-completion, using-git-worktrees, writing-skills…
  È il metodo di lavoro: il CLAUDE.md lo richiama a ogni passo.
- **Design**: `frontend-design` (plugin), `ui-ux-pro-max` (plugin), `impeccable` e la sua famiglia (adapt, animate,
  audit, bolder, clarify, colorize, critique, delight, distill, layout, optimize, overdrive, polish, quieter, shape,
  typeset), `high-end-visual-design`, `design-taste-frontend`, `minimalist-ui`, `industrial-brutalist-ui`,
  `stitch-design-taste` (pensata per l'MCP Stitch di Google: senza, è solo gusto di design), `redesign-existing-projects`,
  `react-best-practices`, `visual-explainer`.
- **GEO/SEO** (da `aaron-he-zhu/seo-geo-claude-skills`, `AgriciDaniel/claude-seo` e un pacchetto «geo-seo-claude»):
  geo*, seo-*, keyword-research, serp-analysis, schema-markup-generator, technical-seo-checker… Alcune usano API a
  pagamento (DataForSEO, Ahrefs, Firecrawl, SE Ranking, Profound): senza chiavi lavorano con ciò che è gratuito.
- **Metodo e produttività**: `get-shit-done` (`/gsd:*`, agenti gsd-*), `gsd-parallel`, `skill-finder` (hook di
  SessionStart in Python: propone skill adatte al progetto), `memory-management`, `split-claude-md`,
  `full-output-enforcement`, `security-audit`, `graphify` (grafo di conoscenza del codice), `hyperresearch` + 18 skill
  di passo (ricerca a più passi; sono skill «renderizzate» dal pacchetto Python hyperresearch 0.13.2: funzionano come
  prompt, il pacchetto serve solo per rigenerarle o per il suo MCP: `uv venv && uv pip install 'hyperresearch[mcp]'`).
- **Media**: `remotion` (video da codice), `real-sfx` e `openverse-sfx` (effetti sonori; real-sfx usa `GEMINI_API_KEY`
  se c'è), `gemini-api-dev` (API Gemini; chiave dell'utente), `web-scraping`, `vexor-cli`.
- **caveman** (clone di `JuliusBrussee/caveman`): si registra da solo come plugin `caveman@skills-dir` e il suo hook
  attiva a ogni sessione la modalità ultra-breve. Nel kit viene installato solo con `CAVEMAN=si`.
- **Hook di Daniele**: `context-alert.js` (sopra), `fix-mcp-auth-cache.js` (toglie supabase/stripe da una cache di
  autenticazione MCP: innocuo senza quei server).

Esclusi di proposito (vedi §2): skill e MCP legati agli account di Daniele, le `synced` di claude.ai, il clone
`wondelai/skills` (non ha `SKILL.md` alla radice, Claude Code non lo carica).

---

## 7. Differenze rispetto alla sandbox di Francesca (perché qui è più semplice)

Francesca è un'ospite sul server di Daniele: utente Linux separato (uid 2000), pm2 di root che lancia la sua CloudCLI
con `runuser`, `deny` sui percorsi di Daniele nei settings, firewall iptables `-m owner` che le chiude i servizi locali,
`/proc` con `hidepid=invisible`, backup orario fatto da root, token Max di Daniele. Qui l'utente **è** il padrone:
niente di tutto questo. I settings del kit (`modelli/settings.json`) sono quelli di Daniele ridotti a ciò che non dipende
dai suoi account; se un giorno l'utente vorrà dare un ambiente a un collega sul suo server, il modello è il repo
`francesca` di Daniele: chiedetelo a lui.

---

## 8. Senza kit: ricostruire dalle fonti pubbliche

Se hai solo questo file: §4.2 a mano (nvm, `install.sh | bash -s 2.1.319`, `npm i -g @cloudcli-ai/cloudcli@1.37.7
pm2@6.0.14`), poi:
```bash
claude plugin marketplace add obra/superpowers-marketplace; claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill; claude plugin marketplace add timescale/pg-aiguide
claude plugin install superpowers@claude-plugins-official; claude plugin install frontend-design@claude-plugins-official
claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill; claude plugin install pg@aiguide
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp
claude mcp add -s user playwright -- npx -y @playwright/mcp@latest --no-sandbox
npx get-shit-done-cc@latest            # GSD: segui le domande (Claude Code, globale)
git clone https://github.com/JuliusBrussee/caveman ~/.claude/skills/caveman          # solo se CAVEMAN=si
git clone https://github.com/nicobailon/visual-explainer ~/.claude/skills/visual-explainer
git clone https://github.com/yfe404/web-scraper ~/.claude/skills/web-scraping
# GEO/SEO: https://github.com/aaron-he-zhu/seo-geo-claude-skills e https://github.com/AgriciDaniel/claude-seo (seguire i loro README)
# impeccable e famiglia: https://github.com/pbakaus/impeccable (seguire il README)
```
CLAUDE.md e settings: riscrivili tu partendo dalla §5 (il modello completo è in questo repo; senza repo, la §5 basta a
rifarlo). `context-alert.js` è di Daniele: senza kit, chiedilo a lui o scrivine uno equivalente (hook UserPromptSubmit +
PostToolUse che legge l'ultimo `usage` dal transcript e avvisa a 650k/850k token).

---

## 9. Manutenzione

- **Aggiornare Claude Code / CloudCLI / pm2**: cambia le versioni in `kit.env`, `scripts/installa-strumenti.sh`, poi
  `scripts/avvia-cloudcli.sh`. Mai l'autoupdater (versioni allineate a quelle di Daniele, che le prova prima).
- **Aggiornare skill e hook del kit**: `git pull` nel kit e `scripts/installa-kit.sh` (senza `--modelli`).
- **Riavviare CloudCLI**: `scripts/avvia-cloudcli.sh`. Mai `pm2 restart cloudcli --update-env` da una shell con `PORT` o
  `NODE_ENV` impostati (l'app cambierebbe porta o modo).
- **Nuovo progetto**: `scripts/nuovo-progetto.sh <cartella> "Nome"`. L'API `create-project` di CloudCLI rifiuta `/root` e
  `/opt` come «system directory»: lo script scrive la riga nella tabella `projects` di `~/.cloudcli/auth.db` come fa il
  watcher (`project_id`, `project_path`, `custom_project_name`, `isArchived`). Dopo un aggiornamento di CloudCLI controlla
  che lo schema sia lo stesso.
- **Password di CloudCLI**: nuovo hash nella tabella `users` di `auth.db` (o DB vuoto e `--registra` di nuovo), poi
  `sync-vault.sh`.
- **Token di login scaduto** (`setup-token` dura 1 anno): `/login` di nuovo o nuovo token in `.env.cloudcli`.

---

## 10. Cose imparate sul server di Daniele (ti risparmiano ore)

- CloudCLI senza `HOST=127.0.0.1` ascolta su 0.0.0.0. Controlla sempre con `ss -ltnp`.
- Il tab «Shell» di CloudCLI apre la CLI di Claude (prima volta: «trust this folder»), non bash. Il tab Terminal è bash.
- CloudCLI al primo accesso chiede nome/email git (onboarding): finiscono in `git config --global`.
- pm2 eredita l'ambiente della shell: `PORT` e `NODE_ENV` di una sessione CloudCLI finiscono nelle app. Sempre
  `env -u PORT -u NODE_ENV pm2 start …`; il config del kit usa `filter_env` per lo stesso motivo.
- Dietro nginx Next.js costruisce `req.url` dal proprio indirizzo di ascolto: i redirect assoluti si fanno da
  `NEXT_PUBLIC_APP_URL`.
- Il `.bashrc` di Ubuntu esce subito nelle shell non interattive: l'ambiente (nvm, PATH) va in `.profile`, altrimenti
  cron e `bash -lc` non trovano `node`.
- Playwright MCP vuole Chromium e le sue librerie di sistema: `npx playwright install --with-deps chromium`.
- Su un server condiviso `/proc` senza `hidepid` mostra a ogni utente la riga di comando degli altri processi, chiavi
  MCP comprese: se ci sono più utenti Linux, `hidepid=invisible` in fstab.
- In modalità auto il classificatore di Claude Code a volte nega `gh repo create` o `git push` («Public Data-Sharing
  Upload») anche con la regola in `settings.json`: non aggirarlo, fermati dopo un tentativo, dillo all'utente e riprova
  quando lo chiede lui (non è deterministico). Le frasi in `autoMode.allow` dei settings servono a questo.
- Lo swap si riempie con raffiche di Chromium/Playwright, non per pressione RAM: `vm.swappiness=10` ha aiutato.
- Una skill clonata con la sua `.git` dentro `~/.claude/skills` viene trattata da git come sottomodulo nei backup: il
  vault le copia senza `.git` (lo fa `sync-vault.sh`).

---

## 11. Come chiudere

Quando tutto il collaudo (§4.9) è verde, scrivi all'utente un riepilogo breve: dove sta cosa (dominio, cartella dei
progetti, kit, vault), cosa è stato automatizzato (cron del vault, pm2 al boot), come si lavora (brainstorming → spec →
piano → Opus; «vai»; i due elenchi), e i due elenchi **Da fare <NOME>** / **Da fare Claude**. Poi commit e push di tutto
ciò che è nato (progetto Benvenuto, vault) e `controllo-backup.sh` pulito. Un file che vive solo sul server è
lavoro non finito: vale anche per il primo giorno.

Buon lavoro, fratello. — Claude (Fable 5.1), server di Daniele, 17/11/2026
