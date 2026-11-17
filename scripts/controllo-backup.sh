#!/bin/bash
# controllo-backup.sh — regola aurea «niente vive solo su questo server». Elenca ciò che NON è al sicuro fuori dal server:
# cartelle di progetto in $SRV senza git o senza remote, commit non pushati, modifiche non committate. Esce con 1 se c'è
# almeno una segnalazione. Lo lancia Claude a fine lavoro; sync-vault.sh ne salva il rapporto nel vault ogni ora.
# Uso: controllo-backup.sh [--fetch]   (--fetch aggiorna i remote prima di contare: più lento)
. "$(dirname "$0")/_comune.sh"
FETCH=0; [ "${1:-}" = "--fetch" ] && FETCH=1
segnalazioni=0
riga() { printf '%-30s %s\n' "$1" "$2"; segnalazioni=$((segnalazioni + 1)); }
echo "# Controllo backup — $(date '+%Y-%m-%d %H:%M') — progetti in $SRV"
for d in "$SRV"/*/; do
  [ -d "$d" ] || continue
  d=${d%/}; n=$(basename "$d")
  if ! git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then riga "$n" "NESSUN GIT: cartella non versionata"; continue; fi
  if ! git -C "$d" remote get-url origin >/dev/null 2>&1; then riga "$n" "NESSUN REMOTE: repo solo locale"; continue; fi
  [ "$FETCH" = 1 ] && git -C "$d" fetch -q origin 2>/dev/null
  if git -C "$d" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    ahead=$(git -C "$d" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
    [ "$ahead" -gt 0 ] && riga "$n" "$ahead commit NON PUSHATI (branch $(git -C "$d" rev-parse --abbrev-ref HEAD))"
  elif [ -z "$(git -C "$d" branch -r --contains HEAD 2>/dev/null)" ]; then
    riga "$n" "commit $(git -C "$d" rev-parse --short HEAD) NON È SU NESSUN BRANCH REMOTO"
  fi
  mod=$(git -C "$d" status --porcelain 2>/dev/null | wc -l)
  [ "$mod" -gt 0 ] && riga "$n" "$mod file modificati/nuovi non committati"
done
if [ "$segnalazioni" -eq 0 ]; then echo "OK: tutto versionato, pushato e pulito."; exit 0; fi
echo "# Segnalazioni: $segnalazioni"; exit 1
