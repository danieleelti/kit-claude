#!/bin/bash
# avvia-cloudcli.sh — avvia (o riavvia) la CloudCLI dell'utente con pm2 su 127.0.0.1:$PORTA_CLOUDCLI e fa pm2 save.
# Prima volta: crea scripts/.env.cloudcli (JWT_SECRET generato; mai stampato) e, con --registra, il primo utente
# (CLOUDCLI_USER e CLOUDCLI_PASSWORD in .env.cloudcli: dopo il primo utente CloudCLI chiude le iscrizioni da sé).
# Da lanciare COME L'UTENTE. Idempotente. Mai `pm2 restart cloudcli --update-env` da una shell con PORT/NODE_ENV strani.
set -euo pipefail
. "$(dirname "$0")/_comune.sh"
[ "$HOME" = "$HOME_UTENTE" ] || { echo "Lancialo come l'utente di kit.env (HOME_UTENTE=$HOME_UTENTE, ora HOME=$HOME)."; exit 1; }
cd "$KIT_DIR_REALE/scripts"
ENVF=.env.cloudcli
if [ ! -f "$ENVF" ]; then
  umask 077
  cat > "$ENVF" <<FINE
# Ambiente della CloudCLI (pm2 «cloudcli»). Fuori da git: va nel vault (sync-vault.sh lo prende: pattern .env*).
SERVER_PORT=$PORTA_CLOUDCLI
HOST=127.0.0.1
HOME=$HOME_UTENTE
DATABASE_PATH=$HOME_UTENTE/.cloudcli/auth.db
CLAUDE_CLI_PATH=$CLAUDE_BIN
CLAUDE_CONFIG_DIR=$CLAUDE_DIR
DISABLE_AUTOUPDATER=1
PATH=$NODE_BIN:$HOME_UTENTE/.local/bin:/usr/local/bin:/usr/bin:/bin
JWT_SECRET=$(openssl rand -hex 32)
# primo utente CloudCLI (solo per --registra; scegli tu i valori, poi lascia qui: è la copia per il vault)
CLOUDCLI_USER=
CLOUDCLI_PASSWORD=
# login a Claude: di norma si fa con /login dalla chat di CloudCLI (abbonamento Max/Pro). In alternativa un token di
# `claude setup-token` (dura 1 anno) qui sotto, oppure ANTHROPIC_API_KEY=... per chi ha solo l'API.
CLAUDE_CODE_OAUTH_TOKEN=
FINE
  echo "creato $PWD/$ENVF (JWT_SECRET generato). Compila CLOUDCLI_USER e CLOUDCLI_PASSWORD, poi rilancia con --registra."
fi
mkdir -p "$HOME_UTENTE/.cloudcli" "$SRV"
PM2() { env -u PORT -u NODE_ENV pm2 "$@"; }
if PM2 describe cloudcli >/dev/null 2>&1; then PM2 restart cloudcli.config.cjs --update-env >/dev/null; else PM2 start cloudcli.config.cjs >/dev/null; fi
PM2 save >/dev/null
for i in $(seq 1 30); do curl -s -o /dev/null "http://127.0.0.1:$PORTA_CLOUDCLI/" && break; sleep 1; done
echo "cloudcli su 127.0.0.1:$PORTA_CLOUDCLI → http $(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORTA_CLOUDCLI/")"
if [ "${1:-}" = "--registra" ]; then
  U=$(grep '^CLOUDCLI_USER=' "$ENVF" | cut -d= -f2-); P=$(grep '^CLOUDCLI_PASSWORD=' "$ENVF" | cut -d= -f2-)
  [ -n "$U" ] && [ -n "$P" ] || { echo "CLOUDCLI_USER/CLOUDCLI_PASSWORD vuoti in $ENVF"; exit 1; }
  C=$(curl -s -o /tmp/cloudcli-registra.$$ -w '%{http_code}' -X POST "http://127.0.0.1:$PORTA_CLOUDCLI/api/auth/register" -H 'content-type: application/json' --data "$(python3 -c 'import json,sys;print(json.dumps({"username":sys.argv[1],"password":sys.argv[2]}))' "$U" "$P")")
  case "$C" in 200|201) echo "primo utente registrato: $U (le iscrizioni ora sono chiuse)";; 403) echo "utente già configurato (403): normale se è la seconda volta";; *) echo "registrazione: http $C — $(head -c 200 /tmp/cloudcli-registra.$$)";; esac
  rm -f /tmp/cloudcli-registra.$$
fi
# pm2 al riavvio del server: il comando lo stampa pm2 stesso (va eseguito una volta, da root se serve)
pm2 startup 2>/dev/null | grep -E '^\s*sudo|^\s*env PATH' | head -1 | sed 's/^/per il riavvio automatico lancia una volta: /' || true
