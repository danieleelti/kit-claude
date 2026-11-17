#!/usr/bin/env node
// Avvisi sulla finestra di contesto (regola di __NOME__, 07/11/2026).
// UserPromptSubmit + PostToolUse: legge dal transcript l'ultimo "usage" e calcola i token in contesto.
//   >= 650k: avviso a __NOME__ (una volta per sessione)
//   >= 850k: secondo avviso + scrivere il file di ripresa (una volta per sessione)
// SessionStart: se per la cartella corrente c'è un file di ripresa recente, lo segnala alla sessione nuova.
// Ripresa: __CLAUDE_DIR__/ripresa/<cartella>.md  (__CLAUDE_DIR__ è nel backup Elestio e nel vault)
const fs = require('fs');
const path = require('path');

const SOGLIA_1 = 650_000;
const SOGLIA_2 = 850_000;
const DIR_RIPRESA = '__CLAUDE_DIR__/ripresa';
const STATO = (id) => `/tmp/claude-context-alert-${id}.json`;

const fileRipresa = (cwd) =>
  path.join(DIR_RIPRESA, (cwd || 'root').replace(/^\/+/, '').replace(/[^A-Za-z0-9._-]+/g, '_') + '.md');

function tokenInContesto(transcript) {
  // legge solo la coda: il transcript può essere di decine di MB
  const fd = fs.openSync(transcript, 'r');
  const size = fs.fstatSync(fd).size;
  const len = Math.min(size, 2_000_000);
  const buf = Buffer.alloc(len);
  fs.readSync(fd, buf, 0, len, size - len);
  fs.closeSync(fd);
  const righe = buf.toString('utf8').split('\n').reverse();
  for (const r of righe) {
    if (!r.includes('"usage"')) continue;
    try {
      const j = JSON.parse(r);
      if (j.isSidechain) continue;
      const u = j.message && j.message.usage;
      if (!u) continue;
      return (u.input_tokens || 0) + (u.cache_creation_input_tokens || 0) + (u.cache_read_input_tokens || 0);
    } catch { /* riga tagliata */ }
  }
  return 0;
}

function esci(evento, testo) {
  process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: evento, additionalContext: testo } }));
  process.exit(0);
}

let input = '';
const guardia = setTimeout(() => process.exit(0), 8000);
process.stdin.on('data', (c) => (input += c));
process.stdin.on('end', () => {
  clearTimeout(guardia);
  try {
    const d = JSON.parse(input);
    const evento = d.hook_event_name;
    const cwd = d.cwd || process.cwd();
    const ripresa = fileRipresa(cwd);

    if (evento === 'SessionStart') {
      if (d.source === 'compact') process.exit(0);
      if (fs.existsSync(ripresa)) {
        const giorni = (Date.now() - fs.statSync(ripresa).mtimeMs) / 86_400_000;
        if (giorni <= 14) {
          esci(evento, `FILE DI RIPRESA presente per questa cartella: ${ripresa} (scritto ${giorni.toFixed(1)} giorni fa da una sessione arrivata a 850k token). ` +
            `All'inizio della risposta dillo a __NOME__ in una riga e chiedigli se riprendere da lì. Se dice sì, leggilo e riparti dal primo punto aperto; ` +
            `quando il lavoro è ripreso, rinominalo in .fatto.md.`);
        }
      }
      process.exit(0);
    }

    if (!d.session_id || !d.transcript_path || !fs.existsSync(d.transcript_path)) process.exit(0);
    const tok = tokenInContesto(d.transcript_path);
    if (tok < SOGLIA_1) process.exit(0);

    let stato = {};
    try { stato = JSON.parse(fs.readFileSync(STATO(d.session_id), 'utf8')); } catch {}
    const k = Math.round(tok / 1000);

    if (tok >= SOGLIA_2 && !stato.s2) {
      stato.s2 = true; stato.s1 = true;
      fs.writeFileSync(STATO(d.session_id), JSON.stringify(stato));
      esci(evento, `ALERT CONTESTO 2/2: la sessione è a circa ${k}k token (soglia 850k). ` +
        `Subito, prima di continuare: 1) scrivi a __NOME__ in testa al messaggio «⚠️ Contesto a ${k}k token: scrivo il file di ripresa». ` +
        `2) Scrivi ${ripresa} (crea la cartella se manca) con: obiettivo del lavoro, cosa è fatto (commit, file, deploy), cosa resta in ordine, ` +
        `decisioni prese e preferenze di __NOME__ emerse, comandi/percorsi utili, problemi aperti, e la prima azione da fare. Deve bastare a una sessione nuova senza questa conversazione. ` +
        `3) Committa/pusha il lavoro in corso. 4) Di' a __NOME__ di aprire una sessione nuova nella stessa cartella: la ripresa verrà proposta in automatico.`);
    }
    if (!stato.s1) {
      stato.s1 = true;
      fs.writeFileSync(STATO(d.session_id), JSON.stringify(stato));
      esci(evento, `ALERT CONTESTO 1/2: la sessione è a circa ${k}k token (soglia 650k). ` +
        `Scrivi a __NOME__ in testa al prossimo messaggio «⚠️ Contesto a ${k}k token (su 1M): a 850k scrivo il file di ripresa e conviene ripartire con una sessione nuova». ` +
        `Da qui chiudi i lavori lunghi a punti stabili (commit e push frequenti).`);
    }
  } catch { /* un hook non deve mai bloccare la sessione */ }
  process.exit(0);
});
