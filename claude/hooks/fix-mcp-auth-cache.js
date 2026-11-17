#!/usr/bin/env node
/**
 * SessionStart hook: rimuove supabase e stripe dalla needs-auth cache
 * così Claude Code non li salta per colpa di auth cache stantia.
 */
const fs = require('fs');
const CACHE_PATH = '__CLAUDE_DIR__/mcp-needs-auth-cache.json';
const TO_REMOVE = ['supabase', 'stripe'];

try {
  if (fs.existsSync(CACHE_PATH)) {
    const cache = JSON.parse(fs.readFileSync(CACHE_PATH, 'utf8'));
    let changed = false;
    for (const key of TO_REMOVE) {
      if (key in cache) {
        delete cache[key];
        changed = true;
      }
    }
    if (changed) {
      fs.writeFileSync(CACHE_PATH, JSON.stringify(cache, null, 2));
    }
  }
} catch (e) {
  // Silenzioso — non bloccare la sessione
}
