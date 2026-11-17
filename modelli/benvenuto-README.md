# Benvenuto, __NOME__

Questo è il tuo spazio per lavorare con Claude Code dal browser. Prova, sbaglia, riprova: ogni cosa che fai qui viene
salvata anche su GitHub, quindi niente va perso.

## Come funziona
- Apri https://__DOMINIO__ ed entra con l'utente e la password scelti all'installazione.
- A sinistra ci sono i **progetti** (cartelle in `__SRV__`). Questo si chiama «Benvenuto». Per un lavoro nuovo chiedi a
  Claude: «crea un progetto nuovo che si chiama X» e lui fa la cartella e il repository GitHub privato.
- Scrivi in chat quello che vuoi ottenere, in italiano. Claude spiega e chiede «vai» prima di fare cose grandi. Alla fine
  di ogni risposta trovi **Da fare __NOME__** e **Da fare Claude**: è la lista di chi fa cosa.
- Se Claude crea un sito o un'app, la avvia sulla «porta __PORTA_ANTEPRIMA__»: la vedi su https://__DOMINIO__/anteprima/
  (chiede una password, la stessa scelta all'installazione).
- In fondo alla chat c'è il selettore del modello: **Fable** per pensare e progettare, **Opus** per eseguire.

## Tre esercizi per cominciare
1. **Una pagina web**: «Fammi una pagina con il titolo "Le mie cose preferite", una lista di tre voci e una foto. Voglio
   vederla sull'anteprima.»
2. **Un file ordinato**: carica un CSV o un Excel qualsiasi (dalla graffetta in chat) e chiedi: «Ordinalo per data e dimmi
   quante righe ci sono per ogni mese».
3. **Un testo**: «Aiutami a scrivere una mail a un cliente che non ha più risposto. Prima fammi tre domande per capire il
   contesto.»

## Regole di casa (le stesse di Daniele, da cui arriva questo ambiente)
- Niente vive solo sul server: ogni progetto è un repository GitHub privato, i segreti stanno in un vault privato.
- Le chiavi e le password non si scrivono mai in chat: vanno in un file `.env` dentro al progetto.
- «vai» è la parola che conferma: Claude chiede solo quella.
