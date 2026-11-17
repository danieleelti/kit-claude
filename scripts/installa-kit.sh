#!/bin/bash
# installa-kit.sh — mette nella configurazione Claude dell'utente il «modo di lavorare» di Daniele:
#   claude/skills, agents, commands, get-shit-done, hooks (+ manifest) → $CLAUDE_DIR, con i segnaposto sostituiti;
#   --modelli: anche CLAUDE.md globale e settings.json dai modelli/ (sovrascrive! la prima volta va messo);
#   MCP context7 + playwright (scope user) e i 4 plugin dai marketplace (salta con --senza-mcp / --senza-plugin).
# Rilanciabile: le skill si aggiungono/aggiornano senza cancellare quelle installate dall'utente; agents, commands,
# get-shit-done e hooks vengono riallineati al kit. Non tocca mai .credentials.json, projects/, sessioni.
# Da lanciare COME L'UTENTE (stessa HOME di kit.env) dopo installa-strumenti.sh.
set -euo pipefail
. "$(dirname "$0")/_comune.sh"
[ "$HOME" = "$HOME_UTENTE" ] || { echo "Lancialo come l'utente di kit.env (HOME_UTENTE=$HOME_UTENTE, ora HOME=$HOME)."; exit 1; }
MODELLI=0; MCP=1; PLUGIN=1
for a in "$@"; do case "$a" in --modelli) MODELLI=1;; --senza-mcp) MCP=0;; --senza-plugin) PLUGIN=0;; *) echo "opzione sconosciuta: $a"; exit 1;; esac; done
SRC=$KIT_DIR_REALE/claude
[ -d "$SRC/skills" ] || { echo "Manca $SRC/skills: il kit è incompleto (serve la cartella claude/ generata da costruisci-kit.sh)."; exit 1; }
mkdir -p "$CLAUDE_DIR" "$SRV"; chmod 700 "$CLAUDE_DIR"

for d in agents commands get-shit-done hooks; do
  [ -d "$SRC/$d" ] || continue
  rsync -a --delete "$SRC/$d/" "$CLAUDE_DIR/$d/"
done
# skill: senza --delete (l'utente può averne aggiunte); caveman solo se richiesto in kit.env
rsync -a $( [ "$CAVEMAN" = si ] || echo "--exclude /caveman --exclude /caveman-commit --exclude /caveman-help --exclude /caveman-review" ) "$SRC/skills/" "$CLAUDE_DIR/skills/"
if [ "$CAVEMAN" != si ]; then rm -rf "$CLAUDE_DIR/skills/caveman" "$CLAUDE_DIR/skills/caveman-commit" "$CLAUDE_DIR/skills/caveman-help" "$CLAUDE_DIR/skills/caveman-review" "$CLAUDE_DIR/.caveman-active"; fi
cp "$SRC/gsd-file-manifest.json" "$SRC/package.json" "$CLAUDE_DIR/" 2>/dev/null || true
mkdir -p "$CLAUDE_DIR/ripresa"
# segnaposto → valori veri (hook e manifest)
{ grep -rlI -e '__HOME__' -e '__CLAUDE_DIR__' -e '__NODE_BIN__' -e '__NOME__' "$CLAUDE_DIR/hooks" "$CLAUDE_DIR/gsd-file-manifest.json" 2>/dev/null || true; } | while read -r f; do sostituisci_segnaposto "$f"; done

if [ "$MODELLI" = 1 ]; then
  for f in CLAUDE.md settings.json; do [ -f "$CLAUDE_DIR/$f" ] && cp -p "$CLAUDE_DIR/$f" "$CLAUDE_DIR/$f.prima-del-kit-$(date +%Y%m%d%H%M)"; done
  cp "$KIT_DIR_REALE/modelli/CLAUDE-globale.md" "$CLAUDE_DIR/CLAUDE.md"
  cp "$KIT_DIR_REALE/modelli/settings.json" "$CLAUDE_DIR/settings.json"
  sostituisci_segnaposto "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/settings.json"
  # blocchi per livello: resta solo quello di kit.env (<!-- principiante --> ... <!-- /principiante -->, idem esperto)
  python3 - "$CLAUDE_DIR/CLAUDE.md" "$LIVELLO" <<'PY'
import re, sys
p, livello = sys.argv[1], sys.argv[2]
t = open(p, encoding='utf-8').read()
for blocco in ('principiante', 'esperto'):
    if blocco == livello:
        t = re.sub(rf'<!-- {blocco} -->\n?|<!-- /{blocco} -->\n?', '', t)
    else:
        t = re.sub(rf'<!-- {blocco} -->.*?<!-- /{blocco} -->\n?', '', t, flags=re.S)
open(p, 'w', encoding='utf-8').write(t)
PY
  chmod 600 "$CLAUDE_DIR/settings.json"
  echo "CLAUDE.md e settings.json scritti dai modelli (livello: $LIVELLO)"
fi

if [ "$MCP" = 1 ]; then
  if [ -x "$CLAUDE_BIN" ]; then
    "$CLAUDE_BIN" mcp get context7 >/dev/null 2>&1 || "$CLAUDE_BIN" mcp add -s user context7 -- npx -y @upstash/context7-mcp >/dev/null && echo "mcp context7: ok"
    "$CLAUDE_BIN" mcp get playwright >/dev/null 2>&1 || "$CLAUDE_BIN" mcp add -s user playwright -- npx -y @playwright/mcp@latest --no-sandbox >/dev/null && echo "mcp playwright: ok"
  else echo "claude non trovato in $CLAUDE_BIN: MCP saltati (prima installa-strumenti.sh)"; fi
fi
if [ "$PLUGIN" = 1 ]; then
  if [ -x "$CLAUDE_BIN" ]; then
    for m in obra/superpowers-marketplace nextlevelbuilder/ui-ux-pro-max-skill timescale/pg-aiguide; do
      "$CLAUDE_BIN" plugin marketplace add "$m" >/dev/null 2>&1 || true
    done
    for p in superpowers@claude-plugins-official frontend-design@claude-plugins-official ui-ux-pro-max@ui-ux-pro-max-skill pg@aiguide; do
      "$CLAUDE_BIN" plugin install "$p" >/dev/null 2>&1 && echo "plugin $p: ok" || echo "plugin $p: NON installato (riprova a mano: claude plugin install $p, oppure /plugin dalla chat)"
    done
  fi
fi

# prova rapida: ogni hook parte senza errori con un input vuoto
ko=0
for h in "$CLAUDE_DIR"/hooks/*.js; do
  echo '{}' | timeout 10 "$NODE_BIN/node" "$h" >/dev/null 2>&1 || { echo "hook con errore: $h"; ko=1; }
done
[ "$ko" = 0 ] && echo "hook: tutti partono"
echo "kit installato in $CLAUDE_DIR: $(ls "$CLAUDE_DIR/skills" | wc -l) skill, $(ls "$CLAUDE_DIR/hooks" | wc -l) hook. Prossimo: scripts/avvia-cloudcli.sh"
