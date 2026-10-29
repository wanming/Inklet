# Inklet

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [Italiano](README.it.md)

Sito web: [getinklet.app](https://getinklet.app)

**Turn rough thoughts into clear text.**

**Inklet** è un assistente di scrittura per macOS che trasforma ciò che digiti, incolli o dici in un testo chiaro, senza uscire dall’app che stai già usando.

Apri il popover di scrittura con la scorciatoia globale, poi digita, incolla o detta nella stessa bozza di partenza modificabile. La dettatura in tempo reale resta dentro l’Assistente di scrittura, così puoi rivedere la trascrizione prima di decidere se trasformarla o inserirla. Sui Mac con chip Apple, le nuove installazioni riconoscono la voce sul tuo Mac, quindi la tua voce non lo lascia mai.

> Questo documento è una traduzione del [README.md](README.md) in inglese. In caso di differenze, fa fede la versione inglese.

## Installazione

GitHub Releases è l’unico canale di distribuzione ufficiale di Inklet. Scarica l’ultimo DMG firmato e autenticato da [GitHub Releases](https://github.com/wanming/Inklet/releases), aprilo e copia Inklet in `/Applications`.

In alternativa puoi usare lo script di installazione qui sotto. Lo script scarica l’ultimo DMG di GitHub Releases e il relativo checksum, verifica la struttura del DMG, il checksum, l’accettazione di Gatekeeper, l’identificatore del bundle, l’Hardened Runtime, gli entitlement effettivi e la firma dell’app, e poi copia Inklet in `/Applications`.

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

## Aggiornamenti

Inklet usa GitHub Releases come unica fonte di aggiornamenti. Le build di produzione controllano su GitHub i metadati pubblici dell’ultima versione stabile circa una volta ogni 24 ore. Un aggiornamento viene annunciato solo dopo che quella versione ha un `Inklet.dmg` caricato; **Visualizza su GitHub** apre la pagina esatta di quella versione. **Installa e riavvia** nell’avviso scarica e installa subito quella versione. Con **Installa aggiornamenti automaticamente** attivo in Impostazioni › Generale, come da impostazione predefinita, Inklet lo fa da solo: scarica `Inklet.dmg` in background, verifica che l’immagine disco superi Gatekeeper e che l’app al suo interno sia firmata dallo stesso sviluppatore di quella in esecuzione, poi sostituisce l’app e si riavvia quando non stai usando Inklet. Se esci da Inklet prima, l’aggiornamento viene applicato senza riaprirlo. Se Inklet non riesce a sostituirsi (ad esempio senza permesso di scrittura sulla sua cartella) o un download o una verifica non riescono, vedrai invece l’avviso, e un’installazione non riuscita non viene mai ritentata da sola. L’avviso mostra le note di quella versione nella lingua dell’interfaccia, oppure in inglese se non sono tradotte.

Usa **Cerca aggiornamenti…** dal menu dell’app per controllare manualmente, sia nell’app di produzione sia in Inklet Local. Inklet Local non pianifica mai controlli automatici e non installa aggiornamenti. Gli errori dei controlli automatici non vengono mostrati, mentre un controllo manuale offre **Riprova**. Se scrittura, dettatura, azioni di selezione, migrazione, una finestra modale o un menu aperto tengono occupato Inklet, l’avviso o l’installazione automatica dell’aggiornamento aspettano che l’app sia inattiva.

Per provare in anteprima le novità, attiva **Aggiornamenti beta** in Impostazioni › Generale. Inklet legge allora l’elenco delle release pubbliche recenti invece della sola ultima versione stabile, e propone anche le versioni beta pubblicate come prerelease di GitHub. Una beta mostra **Beta** accanto alla versione. Disattivare l’opzione non riporta indietro: Inklet resta sulla beta finché non esce una versione stabile più recente.

Dopo un aggiornamento, il primo avvio della nuova versione mostra una sola volta una breve finestra **Novità**, quando Inklet è inattivo e senza togliere lo stato attivo all’app che stai usando. Non compare con una nuova installazione né mentre è aperta la guida di benvenuto. **Registro delle modifiche**, nel menu della barra dei menu, elenca tutte le versioni ed evidenzia quella in uso.

## Prima configurazione

1. Apri Inklet dalla cartella Applicazioni. Per una build dal codice sorgente, esegui `scripts/run-local-app.sh` dalla radice del repository, poi usa `/Applications/Inklet Local.app`.
2. Fai clic sull’icona di Inklet nella barra dei menu e apri **Impostazioni**.
3. Concedi il permesso di Accessibilità quando macOS lo chiede. Inklet usa questo unico permesso generico per leggere le selezioni, eseguire il metodo alternativo di copia configurato, riportare lo stato attivo all’app precedente e incollare i risultati confermati. Inklet resta in background mentre Impostazioni di Sistema è aperto e torna alle impostazioni **Generale** quando lo chiudi.
4. Con una nuova installazione, e una volta dopo l’aggiornamento a questa versione, una guida di benvenuto ti accompagna nella scelta della lingua dell’interfaccia (le nuove installazioni seguono la lingua del sistema), di Accessibilità, del modello di scrittura, del microfono per la Dettatura in tempo reale e delle scorciatoie per aprire Inklet e per dettare, e infine presenta la barra che appare accanto al testo selezionato. Per ripercorrerla in qualsiasi momento, scegli **Guida di benvenuto** nel menu della barra dei menu; ogni passaggio parte dalle impostazioni attuali. Sui chip Apple suggerisce **Integrato** con il modello consigliato e, se lo mantieni, lo scarica in background; il popover di scrittura mostra l’avanzamento e, al termine, funziona anche offline. Per usare invece un provider cloud, sceglilo in **Modelli di IA** e inserisci la sua chiave API. Con OpenAI, il predefinito sui Mac Intel, una sola chiave copre scrittura, dettatura in tempo reale, traduzione della selezione e pronuncia. Con qualsiasi altro provider, la scrittura e la traduzione della selezione usano quel provider, mentre la dettatura e la pronuncia, quando scegli OpenAI per esse, richiedono comunque una chiave API di OpenAI nella scheda Chiavi API della stessa pagina. Per eseguire scrittura e traduzione sul tuo Mac senza alcuna chiave, scegli **Integrato** e scarica un modello, oppure scegli **Ollama** o **LM Studio** se ne usi già uno (vedi [Modelli locali](#modelli-locali)).
5. Configura l’**Assistente di scrittura** con il modello, la scorciatoia di scrittura, le impostazioni di generazione e le modalità prompt che vuoi usare. La **Dettatura in tempo reale** ha una sua pagina nelle Impostazioni: attivala o disattivala, scegli **Su questo Mac** o **OpenAI** per il riconoscimento vocale e scegli la scorciatoia da tenere premuta e il microfono. Sui chip Apple, le nuove installazioni usano **Su questo Mac** e la guida di benvenuto scarica il modello vocale quando vi attivi la dettatura; le configurazioni esistenti restano su OpenAI finché non cambi. Con OpenAI, **Dettatura avanzata** mostra solo il modello di recupero; l’endpoint di recupero non è modificabile. Il modello in tempo reale è fissato da Inklet.
6. Facoltativo: configura l’**Assistente di selezione** con una lingua di traduzione, la modalità **Selezione forzata**, la voce e la velocità della pronuncia con IA, e ascolta un’anteprima della voce nelle Impostazioni.
7. Concedi il permesso del Microfono la prima volta che tieni premuta in modo valido la scorciatoia di dettatura. Aprire Inklet, visitare le Impostazioni o premere la scorciatoia di dettatura fuori dall’editor sorgente attivo non lo richiede.

## Uso quotidiano

Con il testo:

1. Metti lo stato attivo in un qualsiasi campo di testo di un’altra app.
2. Premi `Option+Space`.
3. Cerca una modalità prompt con la ricerca approssimativa (per esempio, `ria` può trovare `Riassumere`), usa `Up` / `Down` per evidenziarla, poi premi `Tab` o `Enter` per confermarla.
4. Digita o incolla il testo grezzo.
5. Premi `Enter` per trasformarlo. Il risultato compare man mano che viene generato; premi `Escape` per fermarlo.
6. Premi di nuovo `Enter` per inserire il risultato, oppure premi `Shift+Command+C` (o fai clic sul pulsante di copia del risultato) per copiarlo.

Con la dettatura:

1. **Apri l’Assistente di scrittura** con `Option+Space`.
2. **Conferma una modalità prompt**. La dettatura non è disponibile nel selettore delle modalità né nell’editor del risultato.
3. **Metti il cursore nella bozza di partenza o seleziona il testo da sostituire.** La dettatura viene inserita nel punto del cursore o sostituisce la selezione.
4. **Tieni premuta la scorciatoia di dettatura configurata** (Option destro per impostazione predefinita) e parla normalmente mentre la bozza si aggiorna sul posto. Una pressione breve non esegue alcuna azione. Se la connessione in tempo reale si interrompe, continua a tenere premuto e a parlare mentre Inklet conserva una registrazione temporanea di recupero.
5. **Rilascia per completare** la trascrizione. Con **Su questo Mac**, il recupero trascrive la registrazione sul tuo Mac. Con OpenAI, se serve il recupero, Inklet invia una sola richiesta a `https://api.openai.com/v1/audio/transcriptions` con la stessa chiave API di OpenAI già usata dalla dettatura in tempo reale. La registrazione temporanea resta in locale finché la richiesta alternativa non inizia davvero, viene caricata al massimo una volta e viene eliminata al termine della sessione.
6. Rivedi e modifica la bozza dettata. La dettatura da sola non esegue la modalità prompt e non inserisce testo in un’altra app.
7. **Premi Return solo quando sei pronto** a eseguire la modalità prompt confermata; premi di nuovo Return solo quando vuoi inserire il risultato.

La scorciatoia di dettatura funziona solo nell’editor sorgente e solo tenendola premuta. Puoi cambiarne il tasto modificatore in Comando destro, Option sinistro o Comando sinistro, oppure disattivare del tutto la dettatura, in **Impostazioni** → **Dettatura in tempo reale**. Escape, la perdita dello stato attivo, la chiusura del popover o l’apertura di un’altra sessione sorgente annullano la dettatura e ripristinano la bozza originale.

## Cosa fa

- Si apre con una scorciatoia globale di macOS. Quella predefinita è `Option+Space`.
- Invia la dettatura in tempo reale all’editor sorgente attivo dell’Assistente di scrittura mentre tieni premuta una scorciatoia con tasto modificatore. Quella predefinita è Option destro.
- Mostra le azioni di selezione dopo che selezioni del testo in un’altra app del Mac e fai una breve pausa, con lettura della selezione in stile EasyDict, traduzione rapida, un prompt **Traduci** personalizzabile, pronuncia con IA, risultati di traduzione ridimensionabili che ricordano l’ultima dimensione e una cache locale di 7 giorni per le traduzioni ripetute.
- Puoi trascinare la barra di selezione o il suo risultato ovunque se coprono qualcosa; i clic funzionano comunque e alla selezione successiva la barra riappare vicino al testo.
- Ignora il testo selezionato più lungo di 1.500 caratteri, per evitare attivazioni accidentali su pagine intere.
- Riproduce direttamente il testo selezionato e, dal risultato della traduzione, può riprodurre sia il testo originale sia quello tradotto.
- Ti permette di scegliere quali pulsanti mostra il menu di selezione e in quale ordine, in **Impostazioni** › **Assistente di selezione** › **Pulsanti del menu**. **Traduci**, **Pronuncia** e qualsiasi modalità prompt possono diventare un pulsante; ne compaiono al massimo quattro alla volta e gli altri finiscono in **Altro**. Un pulsante di modalità prompt esegue quella modalità sul testo selezionato e mostra il risultato nel pannello con i controlli di copia e riproduzione.
- Trasforma il testo con modalità prompt integrate:
  - To Simple and Correct English (nella tua lingua di scrittura, scelta in Impostazioni › Generale; inglese per impostazione predefinita)
  - Summarize (nella tua lingua di traduzione, che per impostazione predefinita segue la lingua dell’interfaccia)
  - To Italian, To Japanese e così via (traduce nella tua lingua di traduzione; per una sola parola mostra significato, pronuncia e frasi di esempio)
  - Voice Cleanup
  - I nomi delle modalità integrate restano in inglese in ogni lingua dell’interfaccia, così le stesse lettere le trovano; indicano le tue lingue finché non le rinomini.
- Mostra il risultato nel popover man mano che viene generato, poi lo inserisce nell’app che aveva lo stato attivo o lo copia con il pulsante di copia del risultato.
- Usa un unico percorso di selezione, indipendente dall’app e basato prima di tutto su Accessibilità. Le azioni di selezione automatiche chiedono prima la selezione ad Accessibilità di macOS e usano il metodo alternativo configurato con gli appunti temporanei solo quando la **Selezione forzata** lo consente. Ogni lettura resta legata al processo sorgente acquisito e si annulla se quel processo termina o perde lo stato attivo.
- Lascia disattivato per impostazione predefinita il `Command+C` simulato. La copia dal menu resta il metodo alternativo sicuro della **Selezione forzata**; per le app senza un menu Copia utilizzabile puoi attivare esplicitamente la copia simulata come alternativa avanzata, ma può interferire con giochi, desktop remoti o macchine virtuali.
- Esegue in sequenza le letture temporanee degli appunti e ripristina lo stato precedente solo finché la stessa lettura detiene ancora il risultato di copia osservato; i contenuti più recenti degli appunti hanno la precedenza. L’attivazione con doppia copia è passiva: usa la copia che l’utente ha già fatto, senza eseguire un’altra copia sintetica né ripristinare dati più vecchi degli appunti. Il clic destro resta nativo e non avvia mai una lettura della selezione.
- Non usa codice di selezione specifico per i browser e non chiede il permesso di Automazione per i browser. Chrome, Safari, Edge e le app native usano lo stesso percorso generico.
- Ti permette di modificare modalità prompt, provider, modello, endpoint personalizzato compatibile con OpenAI, timeout, scorciatoia di scrittura, scorciatoia di dettatura da tenere premuta, microfono, modello di recupero, lingua di traduzione della selezione, prompt **Traduci** della selezione, pulsanti del menu di selezione, modalità **Selezione forzata**, permesso di copia simulata, voce e velocità della pronuncia con IA.
- Mostra una **Cronologia** locale dei risultati di scrittura e di selezione riusciti, con le voci duplicate consecutive raggruppate, testo sorgente e risultato selezionabili, un controllo per copiare il risultato e un’azione per cancellare tutto. Le vecchie voci Voice restano leggibili.
- Scrive e traduce con OpenAI, Anthropic, Google Gemini, DeepSeek, Alibaba Qwen, Moonshot Kimi, Zhipu GLM, MiniMax, SiliconFlow, Volcengine Ark, Tencent Hunyuan, Baichuan, 01.AI Yi, xAI, Groq, Mistral, OpenRouter, Perplexity, Together AI, Cerebras o qualsiasi endpoint personalizzato compatibile con OpenAI, come un server di modelli locale. La pronuncia usa il motore scelto in Da testo a voce, in Modelli di IA: la voce di sistema di macOS (predefinita nelle nuove installazioni, offline e gratuita) oppure OpenAI. La dettatura usa il motore di riconoscimento vocale scelto in **Dettatura in tempo reale**.
- Esegue scrittura e traduzione sul tuo Mac con il motore integrato (Qwen3.5 4B o Gemma 4 E4B, scaricati una sola volta da Hugging Face) o con un server Ollama o LM Studio locale. Non serve alcuna chiave API e il testo resta sul tuo Mac.
- Offre l’interfaccia dell’app in inglese, cinese semplificato, cinese tradizionale, giapponese, coreano, spagnolo, francese, tedesco, portoghese e italiano.
- Adatta i menu di selezione compatti e i controlli con poco spazio delle impostazioni e della scrittura alle etichette tradotte; cambiare lingua aggiorna l’interfaccia aperta e conserva il contenuto che stai scrivendo.

## Stato attuale

Inklet è un MVP in fase iniziale. Il repository attualmente include:

- Uno Swift Package per l’app macOS e il motore di scrittura principale.
- Un’app nella barra dei menu con un popover di scrittura e una finestra delle impostazioni.
- Adattatori dei provider e archiviazione della configurazione.
- Test unitari del comportamento principale.
- Note per i test manuali in [docs/manual-test-checklist.md](docs/manual-test-checklist.md).

## Requisiti

- macOS 14 o successivo.
- Toolchain Swift 6.
- Si consiglia Xcode completo per il supporto a XCTest.
- Il permesso di Accessibilità per Inklet, necessario per la lettura generica della selezione, il metodo alternativo di copia configurato, il ritorno dello stato attivo all’app precedente e l’incolla del risultato generato.
- Il permesso del Microfono per la dettatura in tempo reale mentre tieni premuta la scorciatoia.
- Una chiave API di OpenAI o di un altro provider supportato, oppure un modello locale. La pronuncia e la dettatura richiedono una chiave API di OpenAI solo quando usano OpenAI.

## Modelli locali

Inklet può scrivere e tradurre con un modello che gira sul tuo Mac, così il tuo testo non lo lascia mai e non serve alcuna chiave API.

- **Integrato** (solo chip Apple, predefinito nelle nuove installazioni): scegli **Integrato** come provider, seleziona un modello e fai clic su **Scarica**. Gemma 4 E4B (circa 4,6 GB) è il predefinito per i Mac con 16 GB di memoria o più; Qwen3.5 4B (circa 2,7 GB) è consigliato per 8 GB. In una nuova installazione lo scarica la guida di benvenuto; mentre un modello si scarica, il popover di scrittura ne mostra l’avanzamento, con un pulsante **Scarica** se il modello non c’è ancora. I download riprendono dopo un’interruzione e vengono verificati con uno SHA-256 fissato prima dell’uso. Quando apri il popover di scrittura con **Integrato** selezionato, Inklet avvia il suo server llama.cpp incluso solo sull’indirizzo di loopback e carica il modello, che di solito è pronto quando invii il testo. Sui Mac con 24 GB di memoria o più il modello resta caricato e viene rilasciato solo quando macOS è a corto di memoria; sui Mac più piccoli il server lo rilascia dopo cinque minuti di inattività.
- **Dettatura su questo Mac** (solo chip Apple, predefinita nelle nuove installazioni): la Dettatura in tempo reale riconosce la voce con Qwen3-ASR 0.6B (circa 1 GB), che comprende 30 lingue e il cinese misto all’inglese. Gira sullo stesso motore llama.cpp incluso, in un server separato, ritrascrive ciò che dici circa ogni 0,6 secondi mentre parli e fissa ogni frase a ogni pausa. Sui Mac con 16 GB di memoria o più il modello vocale resta caricato finché la dettatura è attiva; sui Mac più piccoli viene caricato quando si apre il popover di scrittura e rilasciato dopo cinque minuti di inattività. Disattivare la dettatura, o scegliere OpenAI, la ferma. Quando Inklet o macOS usano il cinese tradizionale, la dettatura in cinese viene scritta in caratteri tradizionali.
- **Ollama**: installa [Ollama](https://ollama.com), esegui `ollama pull qwen3.5:4b`, poi scegli **Ollama**. Inklet elenca i modelli che Ollama ha scaricato.
- **LM Studio**: avvia il server locale di LM Studio sulla porta 1234, carica un modello, poi scegli **LM Studio**.

I provider locali hanno almeno 120 secondi per richiesta, così la prima richiesta può caricare il modello. Inklet chiede ai server locali di saltare il "ragionamento", così i piccoli modelli di ragionamento rispondono direttamente. Le build dal codice sorgente compilano il motore integrato con `scripts/build-llama-server.sh`, che richiede `cmake`; se manca, l’app funziona comunque e l’opzione **Integrato** spiega che il motore non è incluso.

## Compilare ed eseguire

Prima di ogni build del bundle dell’app, aumenta sia `INKLET_VERSION` sia `INKLET_BUILD_NUMBER` nel file `VERSION` alla radice. Di norma incrementa la versione di patch; usa incrementi minor o major per modifiche più ampie. Il numero di build deve restare un intero positivo maggiore di qualsiasi numero di build usato in precedenza, anche tra versioni commerciali diverse. Prima di sceglierlo, controlla l’ultima `main`, i tag Git, tutte le release di GitHub (bozze incluse) e i worktree attivi. Inklet usa solo questo numero di build per decidere se un aggiornamento è più recente.

Esegui le build remote del DMG su GitHub solo da `main`, dopo aver unito e inviato le modifiche previste e il `VERSION` aggiornato. Avvia `build-dmg.yml` con `--ref main`.

Per una release ufficiale, verifica che la build sia riuscita e i file finali, sostituisci la descrizione provvisoria con le modifiche in cinese e in inglese rispetto all’ultima release stabile pubblicata e pubblicala come ultima release stabile. Una bozza già verificata può essere pubblicata senza ricompilare né cambiare versione.

Il workflow del DMG controlla prima della build che il numero di build non sia riutilizzato o inferiore; non incrementa automaticamente nessuno dei due valori. Vedi [release version checks](scripts/README.md#release-version-checks) per la verifica manuale. Cambiare la versione di un’app impacchettata richiede di ricompilare, firmare, autenticare e rigenerare i checksum; cambiare solo il titolo della release o il nome del file non aggiorna l’app.

Dalla radice del repository:

```bash
swift build
scripts/run-local-app.sh
```

Usa `scripts/run-local-app.sh` per i test manuali di routine da qualsiasi worktree. Installa e apre l’identità stabile `/Applications/Inklet Local.app`, così le autorizzazioni di Accessibilità e del Portachiavi di macOS restano valide tra una build e l’altra.

Eseguire i test:

```bash
swift test
```

Se i test falliscono perché `XCTest` non è disponibile, installa l’app Xcode completa invece dei soli Command Line Tools.

Controlla tutte le lingue dell’interfaccia con `scripts/check-localization.sh`. Aggiungi `--snapshots` per generare in `.build/localization-audit/` una galleria HTML locale di schermate native sintetiche; il comando ne stampa il percorso. Le pull request e i push su `main` eseguono automaticamente tutti i test unitari e i controlli di localizzazione. Vedi [localization audit](docs/localization-audit.md) per la copertura e i controlli manuali rimanenti.

## Scorciatoie da tastiera

- `Option+Space`: apre il popover di scrittura.
- `Right Option`: tienilo premuto per dettare mentre l’editor sorgente dell’Assistente di scrittura è attivo. Cambia il tasto modificatore o disattiva la dettatura in **Impostazioni** → **Dettatura in tempo reale**; una pressione breve resta senza effetto.
- `Up` / `Down` nel launcher delle modalità: sposta l’evidenziazione tra le modalità prompt ordinate per corrispondenza approssimativa.
- `Tab`, `Return` o `Enter` del tastierino numerico nel launcher delle modalità: conferma la modalità prompt evidenziata e sposta lo stato attivo nell’editor sorgente. Durante una composizione del metodo di input, Return continua a confermare il testo o un candidato; Return con Comando, Maiuscole, Option o Control non conferma una modalità.
- `Enter` nell’editor: trasforma il testo sorgente, inserisce un risultato generato dalla modalità corrente o rigenera con la modalità appena confermata un risultato superato di una modalità precedente.
- `Command+Enter`: inserisce il testo originale senza chiamare il modello.
- `Shift+Command+C`: copia il risultato visibile senza chiudere il popover.
- `Command+Up` / `Command+Down`: scorre tra le modalità prompt visibili.
- Tenere premuto solo `Command`: mostra tutte le scorciatoie nella barra delle azioni. Altrimenti la barra mostra solo il suggerimento di dettatura e il pulsante principale; tutte le scorciatoie funzionano comunque.
- `Escape`: torna indietro di un livello a ogni pressione, dal risultato all’editor sorgente, poi al launcher delle modalità, poi chiude il popover. Durante la trasformazione, interrompe la generazione, scarta il risultato parziale e resta nell’editor.
- `Command+,`: apre le Impostazioni mentre Inklet è attivo.

La ricerca non distingue maiuscole, minuscole e segni diacritici e supporta la corrispondenza dei caratteri in ordine. Le corrispondenze esatte e di prefisso hanno il peso maggiore; quelle consecutive, a inizio parola, più precoci e più compatte di solito si posizionano più in alto.

Quando si apre il launcher delle modalità, l’ultima modalità prompt confermata è evidenziata se è ancora visibile. Un clic evidenzia una modalità; un doppio clic la conferma. Tornare al launcher conserva la bozza e il risultato correnti.

## Struttura del repository

```text
Sources/InkletApp/       macOS app, popover UI, settings UI, menu bar coordination
Sources/InkletCore/      core config, providers, prompts, hotkeys, insertion, state machine
Tests/InkletCoreTests/   unit tests for core behavior
docs/                    QA manuale e informativa sulla privacy
```

## Note di sviluppo

- Mantieni il comportamento dei provider coperto da test unitari mirati.
- Usa [docs/manual-test-checklist.md](docs/manual-test-checklist.md) prima di rilasciare modifiche visibili agli utenti.
- Usa `scripts/run-local-app.sh` invece di un semplice eseguibile SwiftPM o di `open dist/...` per i test manuali di routine, così le autorizzazioni locali di Accessibilità e del Portachiavi restano legate a un’unica identità stabile dell’app.
- Tratta con attenzione i flussi degli appunti e di Accessibilità: sono centrali nell’esperienza dell’app.
- Il progetto è ancora in fase di MVP, quindi il README deve seguire il codice e non i piani futuri.

## Archiviazione locale e aggiornamenti

Le build di produzione e di QA locale usano un’archiviazione separata per bundle e non condividono impostazioni, Cronologia, cache delle traduzioni, dati diagnostici né credenziali del Portachiavi:

- Application Support di produzione: `~/Library/Application Support/com.tomwan.inklet/`
- Application Support locale: `~/Library/Application Support/com.tomwan.inklet.local/`
- Preferenze di produzione: `~/Library/Preferences/com.tomwan.inklet.plist`
- Preferenze locali: `~/Library/Preferences/com.tomwan.inklet.local.plist`
- Chiavi API dei provider: `api-keys.json` nella cartella Application Support corrispondente, leggibile solo dal tuo account utente ed escluso dai backup di Time Machine
- Servizi del Portachiavi usati dalle versioni precedenti: `Inklet.ProviderAPIKey` (produzione) e `Inklet.Local.ProviderAPIKey` (locale)

Le versioni precedenti conservavano le chiavi API nel Portachiavi. La prima volta che serve una chiave, Inklet la copia dal Portachiavi in `api-keys.json` e lascia al suo posto l’elemento del Portachiavi, così tornando a una versione precedente la chiave si trova ancora. Modificare o cancellare una chiave nelle Impostazioni rimuove la copia nel Portachiavi.

Al primo avvio dopo l’aggiornamento dalla vecchia build in sandbox, Inklet copia automaticamente le vecchie preferenze riconosciute, le chiavi API dei provider nel servizio del Portachiavi corrispondente e la Cronologia nell’archiviazione del bundle attuale. Non elimina né modifica l’origine precedente, quindi i vecchi dati restano disponibili per tornare indietro o recuperarli. La cache delle traduzioni, che è sacrificabile, non viene migrata.

Se macOS blocca l’accesso automatico al vecchio contenitore corrispondente, le Impostazioni mantengono disponibile l’azione **Importa vecchi dati…**. L’importazione assistita convalida esattamente la vecchia cartella `Data` del bundle di produzione o locale in esecuzione, la legge solo finché l’autorizzazione corrente del pannello dei file è valida e non salva un segnalibro di accesso permanente.

## Privacy

- Inklet invia le richieste di scrittura e di traduzione della selezione al provider scelto nelle Impostazioni, usando la chiave API di quel provider. Con la voce di sistema di macOS, la pronuncia legge il testo sul tuo Mac; usa OpenAI, con la tua chiave API di OpenAI, solo quando scegli OpenAI per la sintesi da testo a voce. La dettatura usa OpenAI solo quando lo scegli come motore di riconoscimento vocale.
- Con il riconoscimento vocale **Su questo Mac**, l’audio della dettatura e la sua registrazione di recupero vengono elaborati da un server sul tuo Mac e non lo lasciano mai.
- Con il riconoscimento vocale di OpenAI, mentre tieni premuta la scorciatoia di dettatura, l’audio del microfono attivo viene trasmesso direttamente alla trascrizione di OpenAI Realtime. Inklet conserva inoltre una registrazione locale temporanea di recupero. Resta in locale finché la richiesta alternativa non inizia davvero, viene caricata al massimo una volta su `https://api.openai.com/v1/audio/transcriptions` usando la stessa chiave API di OpenAI già usata dalla dettatura in tempo reale, e viene eliminata in qualunque modo termini la sessione.
- Le tue chiavi API sono archiviate localmente sul tuo Mac, una per provider.
- Con i provider **Integrato**, Ollama o LM Studio, le richieste di scrittura e traduzione vanno solo a un server sul tuo Mac. Scaricare un modello integrato invia una richiesta a Hugging Face per il file scelto; non include il tuo testo, l’audio, le chiavi API né le impostazioni.
- Inklet usa il permesso di Accessibilità per la lettura generica della selezione, il metodo alternativo di copia configurato, il ritorno dello stato attivo all’app precedente e l’incolla del testo.
- Inklet usa il permesso del Microfono solo durante una pressione valida della dettatura nell’editor sorgente attivo dell’Assistente di scrittura. Al termine della dettatura resta una bozza modificabile e nulla viene inserito in un’altra app.
- Inklet usa temporaneamente gli appunti per l’inserimento e per le letture alternative di **Selezione forzata** configurate. Una lettura di **Selezione forzata** ripristina gli appunti precedenti solo se il valore copiato temporaneamente da Inklet è ancora quello attuale, e non sovrascrive una modifica esterna successiva degli appunti.
- Inklet salva localmente nella Cronologia il testo sorgente e il risultato delle azioni di scrittura e di selezione riuscite finché non la cancelli nelle Impostazioni, saltando le voci duplicate consecutive. Una bozza dettata non elaborata non crea alcuna voce nella Cronologia; le vecchie voci Voice restano leggibili in locale.
- Le azioni di selezione acquisiscono l’app sorgente e la posizione della selezione, convalidano quella sorgente prima e durante la lettura e usano Accessibilità per leggerne la selezione corrente. Se Accessibilità non restituisce il testo selezionato, la modalità **Selezione forzata** configurata può invocare per un attimo Copia dal menu e leggere il testo risultante dagli appunti tramite la procedura protetta descritta sopra. Il `Command+C` simulato è disattivato per impostazione predefinita e viene eseguito solo dopo un’attivazione avanzata esplicita. Puoi disattivare la **Selezione forzata** nelle Impostazioni. Questo percorso non invia Apple Event destinati ai browser e non chiede il permesso di Automazione per i browser. Premere due volte rapidamente `Command+C` dopo aver selezionato del testo legge esplicitamente la copia che hai già fatto. Inklet non salva il testo semplicemente selezionato, a meno che un’azione riuscita non venga registrata nella Cronologia locale.
- L’Assistente di selezione memorizza in una cache locale per 7 giorni i risultati di traduzione riusciti, usando chiavi di cache con hash, per velocizzare le traduzioni ripetute.
- Quando non è disponibile una traduzione nella cache locale, la traduzione dell’Assistente di selezione invia il testo selezionato e le tue istruzioni **Traduci** personalizzate al provider scelto; un pulsante di modalità prompt invia il testo selezionato e il prompt di quella modalità al provider scelto; la pronuncia invia il testo selezionato a OpenAI solo quando OpenAI è il motore da testo a voce.
- Inklet scarica il catalogo pubblico dei modelli da `models.dev` al massimo una volta al giorno. Questa richiesta non include il tuo testo, l’audio, le chiavi API né le impostazioni dell’app.
- Non inviare testo o audio privati a OpenAI o al provider scelto se non ti fidi delle loro politiche di gestione dei dati.

## Feedback

Scegli **Invia feedback…** dal menu di Inklet nella barra dei menu, oppure [apri una issue](https://github.com/wanming/Inklet/issues/new/choose). Segnalazioni di bug e idee per nuove funzioni sono benvenute; non incollare mai chiavi API o testo privato in una issue.

## Contribuire

Vedi [CONTRIBUTING.md](CONTRIBUTING.md).

## Sicurezza

Vedi [SECURITY.md](SECURITY.md) per la segnalazione delle vulnerabilità e le indicazioni sui dati sensibili.

## Licenza

Inklet è distribuito con [MIT License](LICENSE).
Le note sulle licenze di terze parti si trovano in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
