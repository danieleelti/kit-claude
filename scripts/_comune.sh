#!/bin/bash
# _comune.sh — letto (source) da tutti gli script del kit: carica kit.env e calcola i percorsi derivati.
KIT_DIR_REALE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
KIT_ENV=${KIT_ENV:-$KIT_DIR_REALE/kit.env}
if [ ! -f "$KIT_ENV" ]; then
  echo "Manca $KIT_ENV: copia kit.env.esempio in kit.env e compila i valori (NOME, GITHUB_USER, DOMINIO, HOME_UTENTE...)." >&2
  exit 1
fi
# shellcheck disable=SC1090
. "$KIT_ENV"
: "${NOME:?NOME mancante in kit.env}" "${GITHUB_USER:?GITHUB_USER mancante}" "${DOMINIO:?DOMINIO mancante}" "${HOME_UTENTE:?HOME_UTENTE mancante}"
CLAUDE_DIR=${CLAUDE_DIR:-$HOME_UTENTE/.claude}
SRV=${SRV:-$HOME_UTENTE/progetti}
KIT_DIR=${KIT_DIR:-$KIT_DIR_REALE}
PORTA_CLOUDCLI=${PORTA_CLOUDCLI:-4444}
PORTA_ANTEPRIMA=${PORTA_ANTEPRIMA:-3500}
LIVELLO=${LIVELLO:-principiante}
CAVEMAN=${CAVEMAN:-no}
NODE_V=${NODE_V:-22.23.4}; CLAUDE_V=${CLAUDE_V:-2.1.319}; CLOUDCLI_V=${CLOUDCLI_V:-1.37.7}; PM2_V=${PM2_V:-6.0.14}; NVM_V=${NVM_V:-v0.40.3}
NODE_BIN="$HOME_UTENTE/.nvm/versions/node/v$NODE_V/bin"
CLAUDE_BIN="$HOME_UTENTE/.local/bin/claude"
export PATH="$NODE_BIN:$HOME_UTENTE/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# sostituisce i segnaposto del kit in un file (in place)
sostituisci_segnaposto() {
  sed -i "s#__NODE_BIN__#$NODE_BIN#g; s#__CLAUDE_DIR__#$CLAUDE_DIR#g; s#__HOME__#$HOME_UTENTE#g; s#__SRV__#$SRV#g; s#__KIT_DIR__#$KIT_DIR#g; s#__NOME__#$NOME#g; s#__GITHUB_USER__#$GITHUB_USER#g; s#__DOMINIO__#$DOMINIO#g; s#__PORTA_CLOUDCLI__#$PORTA_CLOUDCLI#g; s#__PORTA_ANTEPRIMA__#$PORTA_ANTEPRIMA#g; s#__DATA__#$(date +%d/%m/%Y)#g" "$@"
}
