#!/bin/bash
# costruisci-kit.sh — (lato Daniele) rigenera la cartella claude/ del kit a partire da /root/.claude, con i segnaposto
# al posto dei percorsi e del nome di Daniele. Si lancia da root sul server Elestio, poi commit + push del kit.
#   __HOME__        → home dell'utente (es. /root, /home/marco)
#   __CLAUDE_DIR__  → CLAUDE_CONFIG_DIR (es. /home/marco/.claude)
#   __NODE_BIN__    → cartella bin di Node (es. /home/marco/.nvm/versions/node/v22.23.4/bin)
#   __NOME__        → nome dell'utente (compare nei messaggi degli hook)
# Esclusi di proposito: skills/synced (skill legate all'account claude.ai, si sincronizzano da sole), skills/skills (clone
# di wondelai/skills senza SKILL.md: non viene caricato), instagram-skills e linkedin-skills di commercialone (usano gli
# account di Daniele), plugins/ (si reinstallano dai marketplace: vedi installa-kit.sh), .git, node_modules, __pycache__.
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SRC=/root/.claude
KIT=$(cd "$(dirname "$0")" && pwd)
DST=$KIT/claude
ESCL=(--exclude '.git' --exclude 'node_modules' --exclude '__pycache__' --exclude '*.pyc' --exclude '.venv' --exclude '.DS_Store')

rm -rf "$DST"; mkdir -p "$DST"
for d in agents commands get-shit-done hooks; do
  [ -d "$SRC/$d" ] || continue
  rsync -a "${ESCL[@]}" --exclude 'synced' "$SRC/$d/" "$DST/$d/"
done
rsync -a "${ESCL[@]}" --exclude '/synced' --exclude '/skills' --exclude '/.trash' "$SRC/skills/" "$DST/skills/"
# skill a livello di progetto di Daniele che valgono anche per gli altri: hyperresearch (ricerca a più passi)
for d in /root/claudecodeui/srv/commercialone/.claude/skills/hyperresearch*/; do
  [ -d "$d" ] && rsync -a "${ESCL[@]}" "$d" "$DST/skills/$(basename "$d")/"
done
cp "$SRC/gsd-file-manifest.json" "$SRC/package.json" "$DST/" 2>/dev/null || true

# segnaposto: percorsi e nome di Daniele → __HOME__, __CLAUDE_DIR__, __NODE_BIN__, __NOME__ (hook e manifest; le skill non ne hanno)
{ grep -rlI -e '/root/' -e 'Daniele' "$DST/hooks" "$DST/gsd-file-manifest.json" 2>/dev/null || true; } \
  | xargs -r sed -i 's#/root/\.nvm/versions/node/v22\.23\.4/bin#__NODE_BIN__#g; s#/root/\.claude#__CLAUDE_DIR__#g; s#/root/#__HOME__/#g; s#Daniele#__NOME__#g'

# controlli: niente segreti nel kit (il kit è un repo e viaggia verso un altro server)
if grep -rIE 'sk-ant-[A-Za-z0-9_-]{8}|AIza[0-9A-Za-z_-]{20}|ghp_[A-Za-z0-9]{20}|github_pat_[A-Za-z0-9_]{20}|xox[bp]-[A-Za-z0-9-]{10}|sbp_[A-Za-z0-9]{20}|fc-[a-f0-9]{24}|sk_(live|test)_[A-Za-z0-9]{10}' "$DST" >/dev/null; then
  echo "KO: nel kit c'è qualcosa che sembra una chiave. Fermo qui, niente commit."; grep -rlIE 'sk-ant-|AIza|ghp_|github_pat_|xox[bp]-|sbp_|fc-[a-f0-9]{24}|sk_(live|test)_' "$DST" | head; exit 1
fi
if find "$DST" \( -name '.env' -o -name '.env.*' -o -name '*credentials*.json' -o -name '*service-account*.json' -o -name '*.pem' -o -name '*.key' \) ! -name '*.example' -print | grep -q .; then
  echo "KO: nel kit ci sono file di segreti. Fermo qui."; exit 1
fi
RESTI=$( { grep -rlI '/root/' "$DST" 2>/dev/null || true; } | wc -l)
[ "$RESTI" -eq 0 ] || { echo "attenzione: $RESTI file citano ancora /root/ (controllare):"; grep -rlI '/root/' "$DST" | head; }

# elenco leggibile del contenuto, con l'origine delle skill quando è nota
{
  echo "# Contenuto di claude/ — generato il $(date '+%d/%m/%Y %H:%M') da costruisci-kit.sh sul server di Daniele"
  echo
  echo "Skill: $(ls "$DST/skills" | wc -l) · agenti: $(ls "$DST/agents" | wc -l) · comandi gsd: $(ls "$DST/commands/gsd" 2>/dev/null | wc -l) · hook: $(ls "$DST/hooks" | wc -l) · get-shit-done $(cat "$DST/get-shit-done/VERSION" 2>/dev/null || echo '?')"
  echo
  echo "| Skill | Origine (quando dichiarata nel file) |"
  echo "|---|---|"
  for d in "$DST"/skills/*/; do
    n=$(basename "$d"); f="$d/SKILL.md"
    src=""
    if [ -d "$SRC/skills/$n/.git" ]; then src="clone di $(git -C "$SRC/skills/$n" remote get-url origin 2>/dev/null)"; fi
    if [ -z "$src" ] && [ -f "$f" ]; then src=$( { grep -m1 -ohE 'https?://github\.com/[A-Za-z0-9_./-]+' "$f" "$d/README.md" 2>/dev/null || true; } | head -1); fi
    case "$n" in hyperresearch*) src="${src:-pacchetto Python hyperresearch 0.13.2 (skill renderizzate dal profilo «full»)}";; esac
    echo "| $n | ${src:-—} |"
  done
} > "$DST/ELENCO.md"
echo "kit costruito: $(du -sh "$DST" | cut -f1), $(ls "$DST/skills" | wc -l) skill, $(ls "$DST/hooks" | wc -l) hook. Ora: git add -A && git commit && git push"
