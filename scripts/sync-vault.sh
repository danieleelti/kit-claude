#!/usr/bin/env bash
# sync-vault.sh — backup dei segreti e dei database SQLite nel repo PRIVATO <GITHUB_USER>/secrets-vault (regola aurea).
# A ogni giro (cron ogni ora): a) copia i .env* reali (non .example/.sample) e i file di segreti (*credentials*.json,
# *service-account*.json, SECRETS*.md, cartelle secrets/) dei progetti in $SRV; b) esporta ogni SQLite con `sqlite3 .dump`
# in <progetto>/db/*.sql (oltre 50 MB: solo il nome in OVERSIZE.txt); c) server/: crontab, .env.cloudcli del kit, vhost nginx,
# pm2 dump, configurazione di Claude Code (CLAUDE.md, settings, hook, agenti, comandi, skill senza .git, memoria, server MCP
# con le loro chiavi), $HOME/SECRETS-BACKUP.md, rapporto di controllo-backup.sh; d) commit + push SOLO se c'è qualcosa di nuovo.
# Uso: sync-vault.sh [--prova]   (--prova: prepara tutto in una cartella temporanea e la elenca, senza git)
set -euo pipefail
. "$(dirname "$0")/_comune.sh"
umask 077
PROVA=0; [ "${1:-}" = "--prova" ] && PROVA=1
VAULT=$HOME_UTENTE/secrets-vault
REMOTE=https://github.com/$GITHUB_USER/secrets-vault.git
MAX_BYTES=$((50 * 1024 * 1024))
ts() { date '+%F %T'; }
exec 9>/tmp/sync-vault-$(id -u).lock
flock -n 9 || { echo "$(ts) già in corso, salto"; exit 0; }

if [ "$PROVA" = 0 ]; then
  if [ ! -d "$VAULT/.git" ]; then
    gh repo view "$GITHUB_USER/secrets-vault" >/dev/null 2>&1 || gh repo create "$GITHUB_USER/secrets-vault" --private --description "Segreti e database del server (backup automatico)" >/dev/null
    git clone -q "$REMOTE" "$VAULT" 2>/dev/null || { mkdir -p "$VAULT"; git -C "$VAULT" init -q; git -C "$VAULT" branch -M main; git -C "$VAULT" remote add origin "$REMOTE"; }
  fi
  chmod 700 "$VAULT"
  git -C "$VAULT" config user.name "$GITHUB_USER"; git -C "$VAULT" config user.email "$GITHUB_USER@users.noreply.github.com"
  git -C "$VAULT" pull -q --rebase 2>/dev/null || true
fi

STAGE=$(mktemp -d); trap 'rm -rf "$STAGE"' EXIT
: > "$STAGE/.oversize"; n_secrets=0; n_db=0
for P in "$SRV"/*/; do
  [ -d "$P" ] || continue
  name=$(basename "$P")
  while IFS= read -r -d '' f; do
    rel=${f#"$P"}; mkdir -p "$STAGE/$name/$(dirname "$rel")"; cp -p "$f" "$STAGE/$name/$rel"; n_secrets=$((n_secrets + 1))
  done < <(find "$P" \( -name node_modules -o -name .git -o -name .next -o -name dist -o -name .venv -o -name venv -o -name __pycache__ \) -prune -o \
             -type f \( -name '.env*' -o -name '*credentials*.json' -o -name '*service-account*.json' -o -name 'SECRETS*.md' -o -path '*/secrets/*' \) \
             ! -name '*.example' ! -name '*.esempio' ! -name '*.sample' ! -name '*.template' ! -name '.gitignore' ! -name '.gitkeep' -print0)
  while IFS= read -r -d '' db; do
    rel=${db#"$P"}; out="$STAGE/$name/db/${rel//\//__}.sql"; mkdir -p "$STAGE/$name/db"
    if ! sqlite3 -readonly "$db" .dump > "$out" 2>"$STAGE/.err"; then echo "$(ts) ERRORE dump $name/$rel: $(head -c 200 "$STAGE/.err")"; rm -f "$out"; continue; fi
    size=$(stat -c %s "$out")
    if [ "$size" -gt "$MAX_BYTES" ]; then echo "$name/$rel  $((size / 1024 / 1024)) MB" >> "$STAGE/.oversize"; echo "$(ts) ⚠️  OLTRE 50 MB, NON committato: $name/$rel"; rm -f "$out"; else n_db=$((n_db + 1)); fi
  done < <(python3 -I - "$P" <<'PY'
import os, sys
root = sys.argv[1]; SKIP = {'node_modules', '.git', '.next', 'dist', '.venv', 'venv', '__pycache__'}
for d, dirs, files in os.walk(root):
    dirs[:] = [x for x in dirs if x not in SKIP]
    for f in files:
        p = os.path.join(d, f)
        if f == '.coverage' or os.path.islink(p): continue
        try:
            if os.path.getsize(p) < 100: continue
            with open(p, 'rb') as h:
                if h.read(16) == b'SQLite format 3\x00': sys.stdout.write(p + '\0')
        except OSError: pass
PY
)
done
[ -f "$HOME_UTENTE/SECRETS-BACKUP.md" ] && cp -p "$HOME_UTENTE/SECRETS-BACKUP.md" "$STAGE/SECRETS-BACKUP.md"
# server: cose fuori dai progetti
S="$STAGE/server"; mkdir -p "$S"
[ -f "$KIT_DIR_REALE/scripts/.env.cloudcli" ] && { cp -p "$KIT_DIR_REALE/scripts/.env.cloudcli" "$S/env.cloudcli"; n_secrets=$((n_secrets + 1)); }
[ -f "$KIT_ENV" ] && cp -p "$KIT_ENV" "$S/kit.env"
crontab -l > "$S/crontab-$(id -un).txt" 2>/dev/null || echo "# (crontab vuoto)" > "$S/crontab-$(id -un).txt"
[ -f "$HOME_UTENTE/.pm2/dump.pm2" ] && cp -p "$HOME_UTENTE/.pm2/dump.pm2" "$S/pm2-dump.json"
for nd in /etc/nginx/sites-available /etc/nginx/conf.d /opt/elestio/nginx/conf.d; do
  [ -d "$nd" ] && [ -r "$nd" ] && { mkdir -p "$S/nginx$(echo "$nd" | tr '/' '-')"; cp -a "$nd/." "$S/nginx$(echo "$nd" | tr '/' '-')/" 2>/dev/null || true; }
done
CL="$S/claude"; mkdir -p "$CL"
for f in CLAUDE.md settings.json settings.local.json keybindings.json; do [ -f "$CLAUDE_DIR/$f" ] && cp -pL "$CLAUDE_DIR/$f" "$CL/$f"; done
for d in hooks ripresa agents commands; do [ -d "$CLAUDE_DIR/$d" ] && { mkdir -p "$CL/$d"; cp -a "$CLAUDE_DIR/$d/." "$CL/$d/"; }; done
for d in "$CLAUDE_DIR"/skills/*/; do
  [ -d "$d" ] || continue; n=$(basename "$d"); [ "$n" = synced ] && continue
  mkdir -p "$CL/skills/$n"; tar -C "$d" --exclude=.git --exclude=node_modules --exclude=.venv --exclude=__pycache__ -cf - . | tar -C "$CL/skills/$n" -xf -
done
for m in "$CLAUDE_DIR"/projects/*/memory; do [ -d "$m" ] || continue; dm="$CL/memory/$(basename "$(dirname "$m")")"; mkdir -p "$dm"; cp -p "$m"/*.md "$dm/" 2>/dev/null || true; done
[ -f "$HOME_UTENTE/.claude.json" ] && python3 -I - "$HOME_UTENTE/.claude.json" "$S/claude-mcp-servers.json" <<'PY' || true
import json, sys
d = json.load(open(sys.argv[1]))
json.dump({'mcpServers': d.get('mcpServers', {}), 'projects': {p: v['mcpServers'] for p, v in d.get('projects', {}).items() if v.get('mcpServers')}}, open(sys.argv[2], 'w'), indent=2, sort_keys=True)
PY
[ -x "$KIT_DIR_REALE/scripts/controllo-backup.sh" ] && "$KIT_DIR_REALE/scripts/controllo-backup.sh" > "$S/controllo-backup.txt" 2>&1 || true
[ -s "$STAGE/.oversize" ] && { echo "# Database oltre 50 MB, NON salvati qui ($(ts))"; cat "$STAGE/.oversize"; } > "$STAGE/OVERSIZE.txt"
cat > "$STAGE/README.md" <<FINE
# secrets-vault (PRIVATO)
Backup automatico dei segreti e dei database del server di $NOME, scritto da \`$KIT_DIR/scripts/sync-vault.sh\` ogni ora. Non modificare a mano.
- \`<progetto>/\`: i file .env* e di segreti; \`<progetto>/db/*.sql\`: dump di ogni SQLite (\`sqlite3 nuovo.db < file.sql\` per ripristinare)
- \`SECRETS-BACKUP.md\`: chiavi di cifratura e segreti non rigenerabili, annotati a mano
- \`server/\`: env della CloudCLI, kit.env, crontab, pm2, vhost nginx, configurazione di Claude Code (claude/) e server MCP con le chiavi
- \`server/controllo-backup.txt\`: cosa non è ancora al sicuro fuori dal server
FINE
rm -f "$STAGE/.oversize" "$STAGE/.err"
if [ "$PROVA" = 1 ]; then echo "PROVA: nessun git. Contenuto preparato (segreti: $n_secrets, database: $n_db):"; (cd "$STAGE" && find . -type f | sort | head -80); exit 0; fi
find "$VAULT" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -a "$STAGE"/. "$VAULT"/
cd "$VAULT"
git ls-files -s | awk '$1=="160000"{print $4}' | while read -r gl; do git rm -q --cached "$gl" 2>/dev/null || true; done
git add -A
if git diff --cached --quiet; then echo "$(ts) nessuna modifica (segreti: $n_secrets, database: $n_db)"; exit 0; fi
git commit -q -m "sync $(ts) — segreti: $n_secrets, database: $n_db"
if ! git push -q -u origin HEAD 2>"$STAGE/push.err"; then echo "$(ts) ❌ PUSH FALLITO:"; sed 's/^/    /' "$STAGE/push.err" | head -20; exit 1; fi
echo "$(ts) ✅ push fatto (segreti: $n_secrets, database: $n_db)"
