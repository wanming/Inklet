# Inklet

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [Italiano](README.it.md)

Website: [getinklet.app](https://getinklet.app)

**Turn rough thoughts into clear text.**

**Inklet** ist ein Schreibassistent für macOS, der getippte, eingefügte oder gesprochene Gedanken in klaren Text verwandelt, ohne dass Sie die App verlassen, in der Sie gerade arbeiten.

Öffnen Sie das Schreib-Popover mit dem globalen Kurzbefehl und tippen, fügen Sie ein oder diktieren Sie in denselben bearbeitbaren Quellentwurf. Das Echtzeitdiktat bleibt im Schreibassistenten, sodass Sie das Transkript prüfen können, bevor Sie entscheiden, ob Sie es umwandeln oder einfügen. Auf Macs mit Apple Chip erkennen Neuinstallationen die Sprache auf Ihrem Mac, sodass Ihre Stimme ihn nie verlässt.

> Dieses Dokument ist eine Übersetzung der englischen [README.md](README.md). Bei Abweichungen gilt die englische Fassung.

## Installation

GitHub Releases ist der einzige offizielle Vertriebsweg von Inklet. Laden Sie das neueste signierte und notarisierte DMG von [GitHub Releases](https://github.com/wanming/Inklet/releases) herunter, öffnen Sie es und kopieren Sie Inklet nach `/Applications`.

Alternativ können Sie das Installationsskript unten verwenden. Es lädt das neueste DMG von GitHub Releases samt Prüfsumme herunter, prüft die DMG-Struktur, die Prüfsumme, die Gatekeeper-Freigabe, die Bundle-ID, die Hardened Runtime, die wirksamen Entitlements und die App-Signatur und kopiert Inklet anschließend nach `/Applications`.

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

## Updates

Inklet nutzt GitHub Releases als einzige Update-Quelle. Produktionsversionen rufen etwa alle 24 Stunden die öffentlichen Metadaten der neuesten stabilen Version von GitHub ab. Ein Update wird erst angekündigt, wenn für diese Version ein `Inklet.dmg` hochgeladen wurde; **Auf GitHub anzeigen** öffnet genau diese Release-Seite. Inklet lädt und installiert Updates nie automatisch.

Mit **Nach Updates suchen…** im App-Menü können Sie in der Produktions-App wie in Inklet Local manuell suchen. Inklet Local plant nie automatische Prüfungen. Fehlgeschlagene automatische Prüfungen bleiben still, eine manuelle Prüfung bietet **Erneut versuchen** an. Ist Inklet durch Schreiben, Diktat, Auswahlaktionen, eine Migration, ein modales Fenster oder ein offenes Menü beschäftigt, wartet der automatische Update-Hinweis, bis die App untätig ist.

Nach einem Update zeigt der erste Start der neuen Version einmalig ein kurzes Fenster **Neuigkeiten**, sobald Inklet untätig ist, ohne der App, die Sie gerade verwenden, den Fokus zu nehmen. Bei einer Neuinstallation oder während der Willkommensassistent geöffnet ist, erscheint es nicht. **Änderungsprotokoll** im Menüleistenmenü listet alle Versionen auf und hebt die laufende Version hervor.

## Ersteinrichtung

1. Öffnen Sie Inklet aus dem Ordner „Programme“. Für einen Build aus dem Quellcode führen Sie `scripts/run-local-app.sh` im Stammverzeichnis des Repositorys aus und verwenden dann `/Applications/Inklet Local.app`.
2. Klicken Sie auf das Inklet-Symbol in der Menüleiste und öffnen Sie **Einstellungen**.
3. Erteilen Sie die Berechtigung für Bedienungshilfen, wenn macOS danach fragt. Inklet nutzt diese eine allgemeine Berechtigung, um Auswahlen zu lesen, den konfigurierten Kopier-Fallback auszuführen, den Fokus an die vorherige App zurückzugeben und bestätigte Ergebnisse einzufügen. Solange die Systemeinstellungen geöffnet sind, bleibt Inklet im Hintergrund und kehrt nach dem Schließen zu den Einstellungen **Allgemein** zurück.
4. Bei einer Neuinstallation und einmalig nach dem Update auf diese Version führt ein Willkommensassistent durch die Sprache der Oberfläche (Neuinstallationen übernehmen die Systemsprache), die Bedienungshilfen, das Schreibmodell, das Mikrofon für das Echtzeitdiktat und die Kurzbefehle zum Öffnen von Inklet und zum Diktieren und stellt zum Schluss die Leiste vor, die neben markiertem Text erscheint. Um ihn jederzeit erneut zu durchlaufen, wählen Sie **Willkommensguide** im Menü der Menüleiste; jeder Schritt beginnt mit Ihren aktuellen Einstellungen. Auf Apple Chips schlägt er **Integriert** mit dem empfohlenen Modell vor und lädt es im Hintergrund, wenn Sie es beibehalten; das Schreib-Popover zeigt den Fortschritt an und funktioniert danach auch offline. Wenn Sie stattdessen einen Cloud-Anbieter nutzen möchten, wählen Sie ihn unter **KI-Modelle** und geben seinen API-Schlüssel ein. Mit OpenAI, der Voreinstellung auf Intel-Macs, deckt ein Schlüssel Schreiben, Echtzeitdiktat, Übersetzung der Auswahl und Aussprache ab. Mit jedem anderen Anbieter laufen Schreiben und Übersetzung der Auswahl über diesen Anbieter, während Diktat und Aussprache, wenn Sie dafür OpenAI wählen, weiterhin einen OpenAI-API-Schlüssel in der Karte „API-Schlüssel“ auf derselben Seite benötigen. Um Schreiben und Übersetzen ganz ohne Schlüssel auf Ihrem Mac auszuführen, wählen Sie **Integriert** und laden ein Modell, oder wählen Sie **Ollama** bzw. **LM Studio**, falls Sie eines davon bereits nutzen (siehe [Lokale Modelle](#lokale-modelle)).
5. Konfigurieren Sie den **Schreibassistenten** mit Modell, Schreib-Kurzbefehl, Generierungseinstellungen und Prompt-Modi. Das **Echtzeitdiktat** hat eine eigene Einstellungsseite: Schalten Sie es ein oder aus, wählen Sie **Auf diesem Mac** oder **OpenAI** für die Spracherkennung und legen Sie den Halte-Kurzbefehl und das Mikrofon fest. Auf Apple Chips nutzen Neuinstallationen **Auf diesem Mac**, und der Willkommensassistent lädt das Sprachmodell, wenn Sie dort das Diktat einschalten; bestehende Konfigurationen bleiben bei OpenAI, bis Sie umstellen. Mit OpenAI bietet **Erweitertes Diktat** nur das Wiederherstellungsmodell an; der Wiederherstellungs-Endpunkt ist nicht bearbeitbar. Das Echtzeitmodell legt Inklet fest.
6. Optional: Konfigurieren Sie den **Auswahlassistenten** mit Übersetzungssprache, Modus **Erzwungene Auswahl**, Stimme und Geschwindigkeit der KI-Aussprache, und hören Sie die Stimme in den Einstellungen probe.
7. Erteilen Sie die Mikrofonberechtigung beim ersten gültigen Halten des Diktat-Kurzbefehls. Das Öffnen von Inklet, das Aufrufen der Einstellungen oder das Drücken des Diktat-Kurzbefehls außerhalb des aktiven Quelleditors fordert sie nicht an.

## Im Alltag

Mit Text:

1. Setzen Sie den Fokus in ein beliebiges Textfeld einer anderen App.
2. Drücken Sie `Option+Space`.
3. Suchen Sie unscharf nach einem Prompt-Modus (zum Beispiel findet `zus` den Modus `Zusammenfassen`), markieren Sie ihn mit `Up` / `Down` und bestätigen Sie ihn mit `Tab` oder `Enter`.
4. Tippen oder fügen Sie Ihren Rohtext ein.
5. Drücken Sie `Enter`, um ihn umzuwandeln. Das Ergebnis erscheint während der Generierung; mit `Escape` stoppen Sie sie.
6. Drücken Sie erneut `Enter`, um das Ergebnis einzufügen, oder `Shift+Command+C` (bzw. die Kopiertaste am Ergebnis), um es stattdessen zu kopieren.

Mit Diktat:

1. **Öffnen Sie den Schreibassistenten** mit `Option+Space`.
2. **Bestätigen Sie einen Prompt-Modus**. In der Modusauswahl und im Ergebniseditor ist kein Diktat möglich.
3. **Setzen Sie die Einfügemarke in den Quellentwurf oder wählen Sie den zu ersetzenden Text aus.** Das Diktat wird an der Einfügemarke eingefügt oder ersetzt die Auswahl.
4. **Halten Sie den konfigurierten Diktat-Kurzbefehl gedrückt** (standardmäßig die rechte Wahltaste) und sprechen Sie normal, während der Entwurf direkt aktualisiert wird. Ein kurzer Tastendruck bewirkt nichts. Fällt die Echtzeitverbindung aus, halten Sie weiter gedrückt und sprechen weiter; Inklet behält eine temporäre Wiederherstellungsaufnahme.
5. **Loslassen, um das Transkript abzuschließen**. Mit **Auf diesem Mac** wird auch die Wiederherstellung auf Ihrem Mac transkribiert. Mit OpenAI sendet Inklet bei Bedarf eine einzige Anfrage an `https://api.openai.com/v1/audio/transcriptions` – mit demselben vorhandenen OpenAI-API-Schlüssel, den das Echtzeitdiktat verwendet. Die temporäre Aufnahme bleibt lokal, bis die Ersatzanfrage tatsächlich beginnt, wird höchstens einmal hochgeladen und am Ende der Sitzung gelöscht.
6. Prüfen und bearbeiten Sie den diktierten Entwurf. Das Diktat allein führt weder den Prompt-Modus aus noch fügt es Text in eine andere App ein.
7. **Drücken Sie Return erst, wenn Sie bereit sind**, den bestätigten Prompt-Modus auszuführen; drücken Sie Return erneut nur, wenn Sie das Ergebnis einfügen möchten.

Der Diktat-Kurzbefehl wirkt nur im Quelleditor und nur durch Halten. Unter **Einstellungen** → **Echtzeitdiktat** können Sie die Sondertaste auf rechte Befehlstaste, linke Wahltaste oder linke Befehlstaste ändern oder das Diktat ganz ausschalten. Escape, Fokusverlust, das Schließen des Popovers oder das Öffnen einer anderen Quellsitzung brechen das Diktat ab und stellen den ursprünglichen Entwurf wieder her.

## Funktionen

- Öffnet sich über einen globalen macOS-Kurzbefehl. Standard ist `Option+Space`.
- Schreibt das Echtzeitdiktat in den aktiven Quelleditor des Schreibassistenten, solange ein Sondertasten-Kurzbefehl gehalten wird. Standard ist die rechte Wahltaste.
- Zeigt Auswahlaktionen, nachdem Sie in einer anderen Mac-App Text ausgewählt und kurz innegehalten haben – mit Auswahl-Lesen im Stil von EasyDict, Schnellübersetzung, einem anpassbaren **Übersetzen**-Prompt, KI-Aussprache, in der Größe veränderbaren Übersetzungsergebnissen, die sich ihre letzte Größe merken, und einem lokalen 7-Tage-Cache für wiederholte Übersetzungen.
- Ignoriert ausgewählten Text mit mehr als 1.500 Zeichen, damit versehentlich markierte ganze Seiten nichts auslösen.
- Spielt ausgewählten Text direkt ab und kann im Übersetzungsergebnis sowohl den Original- als auch den übersetzten Text abspielen.
- Unter **Einstellungen** › **Auswahlassistent** › **Menütasten** wählen Sie, welche Tasten das Auswahlmenü zeigt und in welcher Reihenfolge. **Übersetzen**, **Aussprechen** und jeder Prompt-Modus können eine Taste sein; bis zu vier werden gleichzeitig angezeigt, der Rest landet unter **Mehr**. Eine Prompt-Modus-Taste führt diesen Modus auf den ausgewählten Text aus und zeigt das Ergebnis im Bereich mit Kopier- und Wiedergabesteuerung.
- Wandelt Text mit integrierten Prompt-Modi um:
  - To Simple and Correct English (in Ihre Schreibsprache, wählbar unter Einstellungen › Allgemein; standardmäßig Englisch)
  - Summarize (in Ihre Übersetzungssprache, standardmäßig die Sprache der Oberfläche)
  - To German, To Japanese usw. (übersetzt in Ihre Übersetzungssprache; bei einem einzelnen Wort zeigt es Bedeutung, Aussprache und Beispielsätze)
  - Voice Cleanup
  - Die Namen der integrierten Modi bleiben in jeder Oberflächensprache englisch, damit dieselben Buchstaben sie finden; sie nennen Ihre Sprachen, bis Sie sie umbenennen.
- Streamt das Ergebnis während der Generierung ins Popover und fügt es dann in die zuvor fokussierte App ein oder kopiert es über die Kopiertaste am Ergebnis.
- Verwendet einen einzigen, app-unabhängigen Auswahlweg, der zuerst auf Bedienungshilfen setzt. Automatische Auswahlaktionen fragen die Auswahl zunächst über die macOS-Bedienungshilfen ab und nutzen den konfigurierten temporären Zwischenablage-Fallback nur, wenn **Erzwungene Auswahl** es erlaubt. Jeder Lesevorgang bleibt an den erfassten Quellprozess gebunden und wird abgebrochen, wenn dieser Prozess endet oder den Fokus verliert.
- Lässt simuliertes `Command+C` standardmäßig ausgeschaltet. Das Kopieren über das Menü bleibt der sichere Fallback für **Erzwungene Auswahl**; für Apps ohne nutzbares Kopieren-Menü können Sie simuliertes Kopieren ausdrücklich als erweiterten Fallback aktivieren, das jedoch Spiele, Remote-Desktops oder virtuelle Maschinen stören kann.
- Serialisiert temporäre Zwischenablage-Lesevorgänge und stellt den vorherigen Zustand nur wieder her, solange derselbe Lesevorgang noch das beobachtete Kopierergebnis besitzt; neuere Inhalte der Zwischenablage haben Vorrang. Der Doppel-Kopieren-Auslöser ist passiv: Er nutzt die Kopie, die der Benutzer bereits gemacht hat, ohne eine weitere synthetische Kopie auszulösen oder ältere Zwischenablagedaten wiederherzustellen. Rechtsklick bleibt nativ und startet nie einen Auswahl-Lesevorgang.
- Verwendet keinen browserspezifischen Auswahlcode und fordert keine Automation-Berechtigung für Browser an. Chrome, Safari, Edge und native Apps nutzen denselben allgemeinen Weg.
- Lässt Sie Prompt-Modi, Anbieter, Modell, benutzerdefinierten OpenAI-kompatiblen Endpunkt, Zeitlimit, Schreib-Kurzbefehl, Diktat-Halte-Kurzbefehl, Mikrofon, Wiederherstellungsmodell, Übersetzungssprache der Auswahl, **Übersetzen**-Prompt der Auswahl, Menütasten der Auswahl, Modus **Erzwungene Auswahl**, Erlaubnis für simuliertes Kopieren sowie Stimme und Geschwindigkeit der KI-Aussprache bearbeiten.
- Zeigt einen lokalen **Verlauf** erfolgreicher Schreib- und Auswahlergebnisse, fasst aufeinanderfolgende Duplikate zusammen, macht Quell- und Ergebnistext auswählbar und bietet eine Kopiersteuerung für das Ergebnis sowie eine Aktion zum Löschen aller Einträge. Ältere Voice-Einträge bleiben lesbar.
- Schreibt und übersetzt mit OpenAI, Anthropic, Google Gemini, DeepSeek, Alibaba Qwen, Moonshot Kimi, Zhipu GLM, MiniMax, SiliconFlow, Volcengine Ark, Tencent Hunyuan, Baichuan, 01.AI Yi, xAI, Groq, Mistral, OpenRouter, Perplexity, Together AI, Cerebras oder einem beliebigen benutzerdefinierten OpenAI-kompatiblen Endpunkt, etwa einem lokalen Modellserver. Die Aussprache nutzt die unter **KI-Modelle** › Text zu Sprache gewählte Engine: die macOS-Systemstimme (Voreinstellung bei Neuinstallationen, offline und kostenlos) oder OpenAI. Das Diktat nutzt die im **Echtzeitdiktat** gewählte Spracherkennung.
- Führt Schreiben und Übersetzen auf Ihrem Mac aus – mit der integrierten Engine (Qwen3.5 4B oder Gemma 4 E4B, einmalig von Hugging Face geladen) oder mit einem lokalen Ollama- bzw. LM-Studio-Server. Es ist kein API-Schlüssel nötig, und der Text bleibt auf Ihrem Mac.
- Bietet die App-Oberfläche auf Englisch, vereinfachtem Chinesisch, traditionellem Chinesisch, Japanisch, Koreanisch, Spanisch, Französisch, Deutsch, Portugiesisch und Italienisch.
- Passt kompakte Auswahlmenüs und platzbeschränkte Steuerelemente in Einstellungen und Schreibansicht an übersetzte Beschriftungen an; ein Sprachwechsel aktualisiert die geöffnete Oberfläche und behält den Schreibinhalt bei.

## Aktueller Stand

Inklet ist ein frühes MVP. Das Repository enthält derzeit:

- Ein Swift Package für die macOS-App und die zentrale Schreib-Engine.
- Eine Menüleisten-App mit Schreib-Popover und Einstellungsfenster.
- Anbieter-Adapter und Konfigurationsspeicher.
- Unit-Tests für das Kernverhalten.
- Notizen für manuelle Tests in [docs/manual-test-checklist.md](docs/manual-test-checklist.md).

## Voraussetzungen

- macOS 14 oder neuer.
- Swift-6-Toolchain.
- Für XCTest wird das vollständige Xcode empfohlen.
- Die Berechtigung für Bedienungshilfen für Inklet, erforderlich für das allgemeine Lesen der Auswahl, den konfigurierten Kopier-Fallback, die Rückgabe des Fokus an die vorherige App und das Einfügen des Ergebnisses.
- Die Mikrofonberechtigung für das Echtzeitdiktat, solange der Kurzbefehl gehalten wird.
- Ein API-Schlüssel für OpenAI oder einen anderen unterstützten Anbieter oder ein lokales Modell. Aussprache und Diktat benötigen nur dann einen OpenAI-API-Schlüssel, wenn sie auf OpenAI stehen.

## Lokale Modelle

Inklet kann mit einem Modell schreiben und übersetzen, das auf Ihrem Mac läuft. Ihr Text verlässt ihn nie, und es ist kein API-Schlüssel nötig.

- **Integriert** (nur Apple Chips, Voreinstellung bei Neuinstallationen): Wählen Sie **Integriert** als Anbieter, suchen Sie ein Modell aus und klicken Sie auf **Laden**. Gemma 4 E4B (etwa 4,6 GB) ist die Voreinstellung für Macs mit 16 GB Arbeitsspeicher oder mehr; für 8 GB wird Qwen3.5 4B (etwa 2,7 GB) empfohlen. Bei einer Neuinstallation lädt der Willkommensassistent das Modell; während des Ladens zeigt das Schreib-Popover den Fortschritt, und wenn das Modell noch fehlt, erscheint dort eine Taste **Laden**. Downloads werden nach einer Unterbrechung fortgesetzt und vor der Verwendung gegen einen festgelegten SHA-256-Wert geprüft. Wenn Sie das Schreib-Popover mit ausgewähltem **Integriert** öffnen, startet Inklet seinen mitgelieferten llama.cpp-Server ausschließlich auf der Loopback-Adresse und lädt das Modell, sodass es meist bereit ist, wenn Sie Ihren Text absenden. Auf Macs mit 24 GB Arbeitsspeicher oder mehr bleibt das Modell geladen und wird nur freigegeben, wenn macOS knapp an Speicher ist; auf kleineren Macs gibt der Server es nach fünf Minuten Leerlauf frei.
- **Diktat auf diesem Mac** (nur Apple Chips, Voreinstellung bei Neuinstallationen): Das Echtzeitdiktat erkennt Sprache mit Qwen3-ASR 0.6B (etwa 1 GB), das 30 Sprachen sowie mit Englisch gemischtes Chinesisch versteht. Es läuft auf derselben mitgelieferten llama.cpp-Engine in einem eigenen Server, transkribiert während des Sprechens etwa alle 0,6 Sekunden neu und legt jeden Satz an einer Pause fest. Auf Macs mit 16 GB Arbeitsspeicher oder mehr bleibt das Sprachmodell geladen, solange das Diktat eingeschaltet ist; auf kleineren Macs wird es beim Öffnen des Schreib-Popovers geladen und nach fünf Minuten Leerlauf freigegeben. Das Ausschalten des Diktats oder die Wahl von OpenAI beendet es. Verwendet Inklet oder macOS traditionelles Chinesisch, wird chinesisches Diktat in traditionellen Schriftzeichen geschrieben.
- **Ollama**: Installieren Sie [Ollama](https://ollama.com), führen Sie `ollama pull qwen3.5:4b` aus und wählen Sie dann **Ollama**. Inklet listet die Modelle auf, die Ollama heruntergeladen hat.
- **LM Studio**: Starten Sie den lokalen Server von LM Studio auf Port 1234, laden Sie ein Modell und wählen Sie dann **LM Studio**.

Lokale Anbieter erhalten mindestens 120 Sekunden pro Anfrage, damit die erste Anfrage das Modell laden kann. Inklet bittet lokale Server, das „Nachdenken“ zu überspringen, damit kleine Reasoning-Modelle direkt antworten. Builds aus dem Quellcode kompilieren die integrierte Engine mit `scripts/build-llama-server.sh`, wofür `cmake` nötig ist; fehlt es, läuft die App trotzdem, und die Option **Integriert** erklärt, dass die Engine nicht enthalten ist.

## Bauen und ausführen

Erhöhen Sie vor jedem Build des App-Bundles sowohl `INKLET_VERSION` als auch `INKLET_BUILD_NUMBER` in der Datei `VERSION` im Stammverzeichnis. Normalerweise wird die Patch-Version erhöht; für größere Änderungen die Minor- oder Major-Version. Die Build-Nummer muss eine positive ganze Zahl bleiben, die größer ist als jede zuvor verwendete Build-Nummer, auch über Marketing-Versionen hinweg. Prüfen Sie vor der Wahl den neuesten Stand von `main`, die Git-Tags, alle GitHub-Releases (einschließlich Entwürfen) und aktive Worktrees. Inklet entscheidet allein anhand dieser Build-Nummer, ob ein Update neuer ist.

Starten Sie entfernte DMG-Builds auf GitHub nur von `main`, nachdem die beabsichtigten Änderungen und die aktualisierte `VERSION` gemergt und gepusht wurden. Lösen Sie `build-dmg.yml` mit `--ref main` aus.

Prüfen Sie für ein offizielles Release den erfolgreichen Build und die endgültigen Dateien, ersetzen Sie die Platzhalterbeschreibung durch die chinesischen und englischen Änderungen seit dem letzten veröffentlichten stabilen Release und veröffentlichen Sie es als neuestes stabiles Release. Ein bereits geprüfter Entwurf kann ohne Neubau und ohne Versionsänderung veröffentlicht werden.

Der DMG-Workflow prüft vor dem Build auf wiederverwendete oder niedrigere Build-Nummern; er erhöht keinen der beiden Werte automatisch. Zur manuellen Prüfung siehe [release version checks](scripts/README.md#release-version-checks). Eine Versionsänderung an einer gepackten App erfordert Neubau, Signieren, Notarisieren und neue Prüfsummen; nur den Release-Titel oder Dateinamen zu ändern, aktualisiert die App nicht.

Im Stammverzeichnis des Repositorys:

```bash
swift build
scripts/run-local-app.sh
```

Verwenden Sie `scripts/run-local-app.sh` für routinemäßige manuelle Tests aus jedem Worktree. Es installiert und öffnet die stabile Identität `/Applications/Inklet Local.app`, sodass die Freigaben für Bedienungshilfen und Schlüsselbund unter macOS über Neubauten hinweg erhalten bleiben.

Tests ausführen:

```bash
swift test
```

Schlagen die Tests fehl, weil `XCTest` nicht verfügbar ist, installieren Sie die vollständige Xcode-App statt nur der Command Line Tools.

Prüfen Sie alle Oberflächensprachen mit `scripts/check-localization.sh`. Mit `--snapshots` wird unter `.build/localization-audit/` eine lokale HTML-Galerie synthetischer nativer Oberflächen erzeugt; der Befehl gibt ihren Pfad aus. Pull Requests und Pushes auf `main` führen automatisch alle Unit-Tests und die Lokalisierungsprüfungen aus. Abdeckung und verbleibende manuelle Prüfungen finden Sie unter [localization audit](docs/localization-audit.md).

## Tastaturbedienung

- `Option+Space`: öffnet das Schreib-Popover.
- `Right Option`: gedrückt halten, um zu diktieren, während der Quelleditor des Schreibassistenten aktiv ist. Ändern Sie die Sondertaste oder schalten Sie das Diktat unter **Einstellungen** → **Echtzeitdiktat** aus; ein kurzer Tastendruck bleibt wirkungslos.
- `Up` / `Down` im Modusstarter: bewegt die Markierung durch die nach unscharfer Übereinstimmung sortierten Prompt-Modi.
- `Tab`, `Return` oder `Enter` auf dem Ziffernblock im Modusstarter: bestätigt den markierten Prompt-Modus und setzt den Fokus in den Quelleditor. Während einer Eingabemethoden-Komposition bestätigt Return weiterhin Text oder einen Kandidaten; Return zusammen mit Befehl, Umschalt, Wahl oder Control bestätigt keinen Modus.
- `Enter` im Editor: wandelt den Quelltext um, fügt ein mit dem aktuellen Modus erzeugtes Ergebnis ein oder erzeugt ein veraltetes Ergebnis eines früheren Modus mit dem neu bestätigten Modus neu.
- `Command+Enter`: fügt den Originaltext ein, ohne das Modell aufzurufen.
- `Shift+Command+C`: kopiert das sichtbare Ergebnis, ohne das Popover zu schließen.
- `Command+Up` / `Command+Down`: wechselt durch die sichtbaren Prompt-Modi.
- Nur `Command` gedrückt halten: zeigt alle Kurzbefehle in der Aktionsleiste. Sonst zeigt die Leiste nur den Diktierhinweis und die Hauptschaltfläche; alle Kurzbefehle funktionieren in beiden Fällen.
- `Escape`: geht pro Tastendruck eine Ebene zurück – vom Ergebnis zum Quelleditor, dann zum Modusstarter, dann schließt es das Popover. Während einer Umwandlung stoppt es die Generierung, verwirft das Teilergebnis und bleibt im Editor.
- `Command+,`: öffnet die Einstellungen, während Inklet aktiv ist.

Die Suche ignoriert Groß- und Kleinschreibung sowie diakritische Zeichen und unterstützt Übereinstimmungen von Zeichen in Reihenfolge. Exakte und Präfix-Treffer werden am stärksten gewichtet; aufeinanderfolgende, am Wortanfang liegende, frühere und dichtere Treffer stehen in der Regel weiter oben.

Beim Öffnen des Modusstarters ist der zuletzt bestätigte Prompt-Modus markiert, sofern er noch sichtbar ist. Ein einfacher Klick markiert einen Modus, ein Doppelklick bestätigt ihn. Die Rückkehr zum Starter behält den aktuellen Entwurf und das Ergebnis bei.

## Aufbau des Repositorys

```text
Sources/InkletApp/       macOS app, popover UI, settings UI, menu bar coordination
Sources/InkletCore/      core config, providers, prompts, hotkeys, insertion, state machine
Tests/InkletCoreTests/   unit tests for core behavior
docs/                    manuelle QA und Datenschutzerklärung
```

## Hinweise zur Entwicklung

- Halten Sie das Anbieterverhalten durch gezielte Unit-Tests abgedeckt.
- Nutzen Sie [docs/manual-test-checklist.md](docs/manual-test-checklist.md), bevor Sie für Benutzer sichtbare Änderungen ausliefern.
- Verwenden Sie für routinemäßige manuelle Tests `scripts/run-local-app.sh` statt einer reinen SwiftPM-Programmdatei oder `open dist/...`, damit die lokalen Freigaben für Bedienungshilfen und Schlüsselbund an einer stabilen App-Identität hängen bleiben.
- Behandeln Sie die Abläufe rund um Zwischenablage und Bedienungshilfen sorgfältig; sie sind zentral für die App.
- Das Projekt ist noch im MVP-Stadium, daher soll die README den Code beschreiben und keine künftigen Pläne.

## Lokaler Speicher und Upgrades

Produktions- und lokale QA-Builds nutzen nach Bundle getrennten Speicher und teilen keine Einstellungen, keinen Verlauf, keinen Übersetzungs-Cache, keine Diagnosedaten und keine Schlüsselbund-Zugangsdaten:

- Application Support der Produktion: `~/Library/Application Support/com.tomwan.inklet/`
- Lokaler Application Support: `~/Library/Application Support/com.tomwan.inklet.local/`
- Einstellungen der Produktion: `~/Library/Preferences/com.tomwan.inklet.plist`
- Lokale Einstellungen: `~/Library/Preferences/com.tomwan.inklet.local.plist`
- API-Schlüssel der Anbieter: `api-keys.json` im passenden Application-Support-Ordner, nur für Ihr Benutzerkonto lesbar und von Time-Machine-Backups ausgeschlossen
- Von früheren Versionen genutzte Schlüsselbund-Dienste: `Inklet.ProviderAPIKey` (Produktion) und `Inklet.Local.ProviderAPIKey` (lokal)

Frühere Versionen speicherten API-Schlüssel im Schlüsselbund. Wird ein Schlüssel zum ersten Mal benötigt, kopiert Inklet ihn aus dem Schlüsselbund nach `api-keys.json` und lässt den Schlüsselbundeintrag bestehen, sodass eine Rückkehr zu einer früheren Version ihn weiterhin findet. Das Ändern oder Löschen eines Schlüssels in den Einstellungen entfernt die Kopie im Schlüsselbund.

Beim ersten Start nach einem Upgrade vom alten Sandbox-Build kopiert Inklet automatisch erkannte alte Einstellungen, die API-Schlüssel der Anbieter in den passenden Schlüsselbund-Dienst und den Verlauf in den Speicher des aktuellen Bundles. Die alte Quelle wird weder gelöscht noch verändert, sodass die alten Daten für ein Zurücksetzen oder eine Wiederherstellung erhalten bleiben. Der verzichtbare Übersetzungs-Cache wird nicht übernommen.

Blockiert macOS den automatischen Zugriff auf den passenden alten Container, bieten die Einstellungen dauerhaft die Aktion **Altdaten importieren** an. Der unterstützte Import prüft genau den alten `Data`-Ordner des laufenden Produktions- oder lokalen Bundles, liest ihn nur, solange die aktuelle Freigabe des Dateidialogs gültig ist, und speichert kein dauerhaftes Zugriffslesezeichen.

## Datenschutz

- Inklet sendet Schreib- und Übersetzungsanfragen für die Auswahl an den in den Einstellungen gewählten Anbieter, mit dessen API-Schlüssel. Mit der macOS-Systemstimme liest die Aussprache Text auf Ihrem Mac vor; OpenAI mit Ihrem OpenAI-API-Schlüssel nutzt sie nur, wenn Sie OpenAI für Text zu Sprache wählen. Das Diktat nutzt OpenAI nur, wenn Sie es als Spracherkennung wählen.
- Mit der Spracherkennung **Auf diesem Mac** werden das Diktat-Audio und seine Wiederherstellungsaufnahme von einem Server auf Ihrem Mac verarbeitet und verlassen ihn nie.
- Mit der Spracherkennung von OpenAI wird, solange Sie den Diktat-Kurzbefehl halten, das aktive Mikrofon-Audio direkt an die Transkription von OpenAI Realtime gestreamt. Inklet behält außerdem eine temporäre lokale Wiederherstellungsaufnahme. Sie bleibt lokal, bis die Ersatzanfrage tatsächlich beginnt, wird höchstens einmal an `https://api.openai.com/v1/audio/transcriptions` hochgeladen – mit demselben vorhandenen OpenAI-API-Schlüssel, den das Echtzeitdiktat verwendet – und wird auf jedem Weg, auf dem die Sitzung endet, gelöscht.
- Ihre API-Schlüssel werden lokal auf Ihrem Mac gespeichert, einer pro Anbieter.
- Mit den Anbietern **Integriert**, Ollama oder LM Studio gehen Schreib- und Übersetzungsanfragen nur an einen Server auf Ihrem Mac. Das Laden eines integrierten Modells sendet eine Anfrage für die gewählte Datei an Hugging Face; sie enthält weder Ihren Text noch Audio, API-Schlüssel oder Einstellungen.
- Inklet nutzt die Berechtigung für Bedienungshilfen für das allgemeine Lesen der Auswahl, den konfigurierten Kopier-Fallback, die Rückgabe des Fokus an die vorherige App und das Einfügen von Text.
- Inklet nutzt die Mikrofonberechtigung nur während eines gültigen Diktat-Haltens im aktiven Quelleditor des Schreibassistenten. Nach dem Diktat bleibt ein bearbeitbarer Entwurf, und es wird nichts in eine andere App eingefügt.
- Inklet nutzt die Zwischenablage vorübergehend zum Einfügen und für konfigurierte Fallback-Lesevorgänge der **Erzwungenen Auswahl**. Ein solcher Lesevorgang stellt die vorherige Zwischenablage nur wieder her, wenn der von Inklet vorübergehend kopierte Wert noch aktuell ist, und überschreibt keine spätere externe Änderung der Zwischenablage.
- Inklet speichert Quell- und Ergebnistext erfolgreicher Schreib- und Auswahlaktionen lokal im Verlauf, bis Sie ihn in den Einstellungen löschen, und überspringt dabei aufeinanderfolgende Duplikate. Ein unverarbeiteter diktierter Entwurf erzeugt keinen Verlaufseintrag; ältere Voice-Einträge bleiben lokal lesbar.
- Auswahlaktionen erfassen die Quell-App und die Position der Auswahl, prüfen diese Quelle vor und während des Lesens und lesen ihre aktuelle Auswahl über die Bedienungshilfen. Liefern die Bedienungshilfen keinen ausgewählten Text, kann der konfigurierte Modus **Erzwungene Auswahl** kurz „Kopieren“ im Menü auslösen und den resultierenden Text der Zwischenablage über den oben beschriebenen geschützten Ablauf lesen. Simuliertes `Command+C` ist standardmäßig aus und läuft nur nach ausdrücklicher Aktivierung der erweiterten Option. Sie können **Erzwungene Auswahl** in den Einstellungen ausschalten. Dieser Weg sendet keine an Browser gerichteten Apple Events und fordert keine Automation-Berechtigung für Browser an. Zweimal schnell `Command+C` nach dem Auswählen von Text liest ausdrücklich die Kopie, die Sie bereits gemacht haben. Inklet speichert bloß ausgewählten Text nicht, es sei denn, eine erfolgreiche Aktion wird im lokalen Verlauf festgehalten.
- Der Auswahlassistent speichert erfolgreiche Übersetzungen 7 Tage lang lokal mit gehashten Cache-Schlüsseln zwischen, um wiederholte Übersetzungen zu beschleunigen.
- Ist keine lokal zwischengespeicherte Übersetzung vorhanden, sendet die Übersetzung des Auswahlassistenten den ausgewählten Text und Ihre eigenen **Übersetzen**-Anweisungen an den gewählten Anbieter; eine Prompt-Modus-Taste sendet den ausgewählten Text und den Prompt dieses Modus an den gewählten Anbieter; die Aussprache sendet den ausgewählten Text nur dann an OpenAI, wenn OpenAI die Engine für Text zu Sprache ist.
- Inklet ruft den öffentlichen Modellkatalog höchstens einmal pro Tag von `models.dev` ab. Diese Anfrage enthält weder Ihren Text noch Audio, API-Schlüssel oder App-Einstellungen.
- Senden Sie keine privaten Texte oder Aufnahmen an OpenAI oder den gewählten Anbieter, wenn Sie deren Datenschutzrichtlinien nicht vertrauen.

## Feedback

Wählen Sie **Feedback senden…** im Menüleistenmenü von Inklet oder [eröffnen Sie ein Issue](https://github.com/wanming/Inklet/issues/new/choose). Fehlerberichte und Ideen für Funktionen sind willkommen; fügen Sie niemals API-Schlüssel oder private Texte in ein Issue ein.

## Mitwirken

Siehe [CONTRIBUTING.md](CONTRIBUTING.md).

## Sicherheit

Siehe [SECURITY.md](SECURITY.md) für das Melden von Sicherheitslücken und Hinweise zu sensiblen Daten.

## Lizenz

Inklet wird unter der [MIT License](LICENSE) veröffentlicht.
Hinweise zu Drittanbietern stehen in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
