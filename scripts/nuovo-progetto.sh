#!/bin/bash
# nuovo-progetto.sh — crea un progetto nel posto giusto e lo rende visibile in CloudCLI.
# Uso: nuovo-progetto.sh <cartella> [Nome visualizzato] [--senza-github]
# Fa: cartella $SRV/<cartella> con README/.gitignore/CLAUDE.md (dal modello), git init + commit, repo PRIVATO GitHub
#     <GITHUB_USER>/<cartella> + push, riga nella tabella projects di CloudCLI (l'API create-project di CloudCLI rifiuta
#     /root e /opt come «system directory»: la riga si inserisce come fa il watcher). Idempotente: salta ciò che esiste già.
set -euo pipefail
. "$(dirname "$0")/_comune.sh"
NOME_P=${1:?uso: nuovo-progetto.sh <cartella> [Nome visualizzato] [--senza-github]}
VISTA=${2:-$NOME_P}; [ "$VISTA" = "--senza-github" ] && VISTA=$NOME_P
GITHUB=1; for a in "$@"; do [ "$a" = "--senza-github" ] && GITHUB=0; done
D=$SRV/$NOME_P
mkdir -p "$D"; cd "$D"
if [ ! -f README.md ]; then
  { echo "# $VISTA"; echo; echo "Progetto creato il $(date '+%d/%m/%Y') sul server di $NOME. Cartella \`$D\`; repo privato GitHub \`$GITHUB_USER/$NOME_P\`."; } > README.md
fi
[ -f .gitignore ] || printf '%s\n' 'node_modules/' '.env' '.env.*' '!.env.example' '*.db' '*.sqlite' '*.sqlite3' '.next/' 'dist/' '__pycache__/' '.venv/' '*.log' '.DS_Store' > .gitignore
if [ ! -f CLAUDE.md ]; then
  cp "$KIT_DIR_REALE/modelli/CLAUDE-progetto.md" CLAUDE.md
  sed -i "s#__CARTELLA__#$D#g; s#__PROGETTO__#$NOME_P#g; s#__VISTA__#$VISTA#g" CLAUDE.md
  sostituisci_segnaposto CLAUDE.md
fi
if [ ! -d .git ]; then git init -q; git branch -M main; fi
# identità git: se l'utente non l'ha ancora impostata (CloudCLI la chiede al primo accesso), si usa quella di GitHub solo per questo repo
[ -n "$(git config user.email || true)" ] || { git config user.name "$GITHUB_USER"; git config user.email "$GITHUB_USER@users.noreply.github.com"; }
git add -A
git diff --cached --quiet || git commit -q -m "Progetto $VISTA: cartella iniziale"
if [ "$GITHUB" = 1 ]; then
  gh repo view "$GITHUB_USER/$NOME_P" >/dev/null 2>&1 || gh repo create "$GITHUB_USER/$NOME_P" --private --description "Progetto $VISTA" >/dev/null
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$GITHUB_USER/$NOME_P.git"
  git push -q -u origin main
fi
DB=$HOME_UTENTE/.cloudcli/auth.db
if [ -f "$DB" ]; then
  python3 - "$DB" "$D" "$VISTA" <<'PY'
import sqlite3, sys, uuid
db, path, nome = sys.argv[1], sys.argv[2], sys.argv[3]
c = sqlite3.connect(db, timeout=5); c.execute('PRAGMA busy_timeout = 5000')
if not c.execute("select 1 from sqlite_master where type='table' and name='projects'").fetchone():
    print('CloudCLI: tabella projects assente (apri CloudCLI una volta), progetto non registrato')
elif c.execute('select 1 from projects where project_path=?', (path,)).fetchone():
    print('CloudCLI: progetto già registrato')
else:
    c.execute('INSERT INTO projects (project_id, project_path, custom_project_name, isArchived) VALUES (?,?,?,0)', (str(uuid.uuid4()), path, nome)); c.commit()
    print('CloudCLI: progetto registrato')
c.close()
PY
else echo "CloudCLI: $DB non c'è ancora (avvia-cloudcli.sh): rilancia questo script dopo, per la riga in CloudCLI"; fi
echo "OK: $D$( [ "$GITHUB" = 1 ] && echo " → https://github.com/$GITHUB_USER/$NOME_P (pushato)" ) — nome in CloudCLI: «$VISTA»"
