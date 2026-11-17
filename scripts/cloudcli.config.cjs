// cloudcli.config.cjs — processo pm2 «cloudcli» (Claude Code UI nel browser). Lo usa scripts/avvia-cloudcli.sh.
// Legge l'ambiente da .env.cloudcli (stessa cartella, fuori da git) e il kit.env per i percorsi.
// filter_env: il processo NON eredita PORT e NODE_ENV della shell (CloudCLI altrimenti cambierebbe porta/modo).
const fs = require('fs');
const path = require('path');
function leggiEnv(file) {
  const out = {};
  if (!fs.existsSync(file)) return out;
  for (const riga of fs.readFileSync(file, 'utf8').split('\n')) {
    const m = riga.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (m) out[m[1]] = m[2].replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1');
  }
  return out;
}
const kit = leggiEnv(process.env.KIT_ENV || path.join(__dirname, '..', 'kit.env'));
const home = kit.HOME_UTENTE || process.env.HOME;
const nodeBin = `${home}/.nvm/versions/node/v${kit.NODE_V || '22.23.4'}/bin`;
const env = leggiEnv(path.join(__dirname, '.env.cloudcli'));
delete env.CLOUDCLI_USER; delete env.CLOUDCLI_PASSWORD; // servono solo alla registrazione del primo utente, non all'app
if (!env.CLAUDE_CODE_OAUTH_TOKEN) delete env.CLAUDE_CODE_OAUTH_TOKEN;
module.exports = {
  apps: [{
    name: 'cloudcli',
    script: `${nodeBin}/cloudcli`,
    args: ['start'],
    interpreter: `${nodeBin}/node`,
    cwd: (kit.SRV || `${home}/progetti`).replace('$HOME_UTENTE', home),
    filter_env: ['PORT', 'NODE_ENV'],
    env,
    autorestart: true,
    max_restarts: 10,
    out_file: `${home}/.cloudcli/pm2-out.log`,
    error_file: `${home}/.cloudcli/pm2-err.log`,
  }],
};
