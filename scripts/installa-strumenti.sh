#!/bin/bash
# installa-strumenti.sh — installa nella home dell'utente: nvm + Node, Claude Code nativo, CloudCLI, pm2, gh (+ uv con --con-uv).
# Da lanciare COME L'UTENTE che userà Claude (root o no). Idempotente: se la versione c'è già non reinstalla.
# Se è root e c'è apt, mette anche i pacchetti di sistema (git, python3, sqlite3, rsync, curl, openssl).
set -euo pipefail
. "$(dirname "$0")/_comune.sh"
[ "$HOME" = "$HOME_UTENTE" ] || { echo "Lancialo come l'utente di kit.env (HOME_UTENTE=$HOME_UTENTE, ora HOME=$HOME)."; exit 1; }
CON_UV=0; [ "${1:-}" = "--con-uv" ] && CON_UV=1

if [ "$(id -u)" -eq 0 ] && command -v apt-get >/dev/null; then
  apt-get install -y -qq git python3 sqlite3 rsync curl openssl ca-certificates >/dev/null 2>&1 || echo "apt: qualcosa non è andato, controlla a mano (git python3 sqlite3 rsync curl openssl)"
  command -v gh >/dev/null || apt-get install -y -qq gh >/dev/null 2>&1 || true
fi

# 1) nvm (nel .bashrc; il blocco sotto lo rende disponibile anche alle shell non interattive)
if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_V/install.sh" | PROFILE="$HOME/.bashrc" bash >/dev/null
fi
# 2) ambiente per TUTTE le shell (il .bashrc di Ubuntu esce subito se la shell non è interattiva: pm2, cron, bash -lc)
if ! grep -q '# >>> kit-claude >>>' "$HOME/.profile" 2>/dev/null; then
  cat >> "$HOME/.profile" <<'FINE'

# >>> kit-claude >>>
export DISABLE_AUTOUPDATER=1
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
export PATH
# <<< kit-claude <<<
FINE
fi
grep -q 'DISABLE_AUTOUPDATER' "$HOME/.bashrc" 2>/dev/null || printf '\nexport DISABLE_AUTOUPDATER=1\nexport PATH=$HOME/.local/bin:$PATH\n' >> "$HOME/.bashrc"

export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"
# 3) Node
nvm ls "$NODE_V" >/dev/null 2>&1 || nvm install "$NODE_V" >/dev/null
nvm alias default "$NODE_V" >/dev/null; nvm use "$NODE_V" >/dev/null
# 4) Claude Code nativo, versione fissa
if ! "$CLAUDE_BIN" --version 2>/dev/null | grep -q "^$CLAUDE_V "; then
  curl -fsSL https://claude.ai/install.sh | bash -s "$CLAUDE_V"
fi
# 5) CloudCLI e pm2 nel Node di nvm
cloudcli --version 2>/dev/null | grep -q "$CLOUDCLI_V" || npm i -g "@cloudcli-ai/cloudcli@$CLOUDCLI_V" >/dev/null
pm2 -v 2>/dev/null | grep -qx "$PM2_V" || npm i -g "pm2@$PM2_V" >/dev/null
# 6) gh senza apt: binario nella home
if ! command -v gh >/dev/null; then
  GH_V=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | python3 -c "import sys,json;print(json.load(sys.stdin)['tag_name'].lstrip('v'))")
  T=$(mktemp -d); curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_V}/gh_${GH_V}_linux_amd64.tar.gz" -o "$T/gh.tgz"
  tar -xzf "$T/gh.tgz" -C "$T"; mkdir -p "$HOME/.local/bin"; install -m 755 "$T/gh_${GH_V}_linux_amd64/bin/gh" "$HOME/.local/bin/gh"; rm -rf "$T"
fi
# 7) uv (Python moderno, serve a hyperresearch e a qualche skill): solo con --con-uv
if [ "$CON_UV" = 1 ] && ! command -v uv >/dev/null; then curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null; fi

echo "node $(node -v) | claude $("$CLAUDE_BIN" --version) | cloudcli $(cloudcli --version) | pm2 $(pm2 -v) | gh $(gh --version | head -1 | cut -d' ' -f3) | python $(python3 --version | cut -d' ' -f2)"
echo "strumenti: ok. Prossimo: scripts/installa-kit.sh --modelli"
