# Inklet

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [Italiano](README.it.md)

Site web : [getinklet.app](https://getinklet.app)

**Turn rough thoughts into clear text.**

**Inklet** est un assistant d’écriture pour macOS qui transforme ce que vous tapez, collez ou dites en un texte clair, sans quitter l’app que vous utilisez déjà.

Ouvrez le popover d’écriture avec le raccourci global, puis tapez, collez ou dictez dans le même brouillon source modifiable. La dictée en temps réel reste dans l’Assistant de rédaction : vous pouvez relire la transcription avant de décider de la transformer ou de l’insérer. Sur les Mac avec puce Apple, les nouvelles installations reconnaissent la parole sur votre Mac, si bien que votre voix ne le quitte jamais.

> Ce document est une traduction de [README.md](README.md), en anglais. En cas de différence, la version anglaise fait foi.

## Installation

GitHub Releases est le seul canal de distribution officiel d’Inklet. Téléchargez le dernier DMG signé et notarié depuis [GitHub Releases](https://github.com/wanming/Inklet/releases), ouvrez-le et copiez Inklet dans `/Applications`.

Vous pouvez aussi utiliser le script d’installation ci-dessous. Il télécharge le dernier DMG de GitHub Releases et sa somme de contrôle, vérifie la structure du DMG, la somme de contrôle, l’acceptation par Gatekeeper, l’identifiant du bundle, le Hardened Runtime, les entitlements effectifs et la signature de l’app, puis copie Inklet dans `/Applications`.

```bash
curl -fsSL https://raw.githubusercontent.com/wanming/Inklet/main/scripts/install.sh | bash
```

## Mises à jour

Inklet utilise GitHub Releases comme unique source de mises à jour. Les versions de production consultent sur GitHub les métadonnées publiques de la dernière version stable environ une fois toutes les 24 heures. Une mise à jour n’est annoncée qu’une fois que cette version contient un `Inklet.dmg` téléversé ; **Voir sur GitHub** ouvre la page exacte de cette version. Inklet ne télécharge ni n’installe jamais de mise à jour automatiquement.

Utilisez **Rechercher des mises à jour…** dans le menu de l’app pour vérifier manuellement, dans l’app de production comme dans Inklet Local. Inklet Local ne planifie jamais de vérification automatique. Les échecs des vérifications automatiques restent silencieux, tandis qu’une vérification manuelle propose **Réessayer**. Si l’écriture, la dictée, les actions de sélection, une migration, une fenêtre modale ou un menu ouvert occupent Inklet, l’avis de mise à jour automatique attend que l’app soit inactive.

Après une mise à jour, le premier lancement de la nouvelle version affiche une seule fois une courte fenêtre **Nouveautés**, lorsque Inklet est inactif et sans voler le focus à l’app que vous utilisez. Elle n’apparaît ni lors d’une nouvelle installation ni pendant que le guide de bienvenue est ouvert. **Historique des versions**, dans le menu de la barre des menus, liste toutes les versions et met en évidence celle que vous utilisez.

## Première configuration

1. Ouvrez Inklet depuis le dossier Applications. Pour une version compilée depuis les sources, exécutez `scripts/run-local-app.sh` à la racine du dépôt, puis utilisez `/Applications/Inklet Local.app`.
2. Cliquez sur l’icône d’Inklet dans la barre des menus et ouvrez **Réglages**.
3. Accordez l’autorisation Accessibilité lorsque macOS la demande. Inklet utilise cette seule autorisation générique pour lire les sélections, effectuer le repli par copie configuré, rendre le focus à l’app précédente et coller les résultats confirmés. Inklet reste en arrière-plan pendant que Réglages Système est ouvert et revient aux réglages **Général** quand vous le fermez.
4. Lors d’une nouvelle installation, et une fois après la mise à jour vers cette version, un guide de bienvenue vous accompagne pour la langue de l’interface (les nouvelles installations suivent la langue du système), l’Accessibilité, le modèle d’écriture, le micro de la Dictée en temps réel et les raccourcis pour ouvrir Inklet et dicter, puis présente la barre qui apparaît à côté du texte sélectionné. Pour le parcourir à nouveau à tout moment, choisissez **Guide de bienvenue** dans le menu de la barre des menus ; chaque étape part de vos réglages actuels. Sur puce Apple, il propose **Intégré** avec le modèle recommandé et le télécharge en arrière-plan si vous le gardez ; le popover d’écriture affiche la progression et fonctionne hors ligne une fois le téléchargement terminé. Pour utiliser plutôt un fournisseur cloud, choisissez-le dans **Modèles d’IA** et saisissez sa clé d’API. Avec OpenAI, le choix par défaut sur les Mac Intel, une seule clé couvre l’écriture, la dictée en temps réel, la traduction de la sélection et la prononciation. Avec tout autre fournisseur, l’écriture et la traduction de la sélection passent par ce fournisseur, tandis que la prononciation, ainsi que la dictée quand vous choisissez OpenAI pour elle, nécessitent toujours une clé d’API OpenAI dans la carte Clés API de la même page. Pour exécuter l’écriture et la traduction sur votre Mac sans aucune clé, choisissez **Intégré** et téléchargez un modèle, ou choisissez **Ollama** ou **LM Studio** si vous utilisez déjà l’un d’eux (voir [Modèles locaux](#modèles-locaux)).
5. Configurez l’**Assistant de rédaction** avec le modèle, le raccourci d’écriture, les réglages de génération et les modes de prompt de votre choix. La **Dictée en temps réel** a sa propre page de réglages : activez-la ou désactivez-la, choisissez **Sur ce Mac** ou **OpenAI** pour la reconnaissance vocale, et choisissez le raccourci à maintenir et le micro. Sur puce Apple, les nouvelles installations utilisent **Sur ce Mac**, et le guide de bienvenue télécharge le modèle vocal quand vous y activez la dictée ; les configurations existantes restent sur OpenAI jusqu’à ce que vous changiez. Avec OpenAI, **Dictée avancée** n’expose que le modèle de récupération ; le point de terminaison de récupération n’est pas modifiable. Le modèle temps réel est fixé par Inklet.
6. Facultatif : configurez l’**Assistant de sélection** avec une langue de traduction, le mode **Sélection forcée**, la voix et la vitesse de la prononciation par IA, puis écoutez un aperçu de la voix dans les réglages.
7. Accordez l’autorisation Microphone lors du premier maintien valide du raccourci de dictée. Ouvrir Inklet, consulter les réglages ou appuyer sur le raccourci de dictée en dehors de l’éditeur source actif ne la demande pas.

## Utilisation au quotidien

Avec du texte :

1. Placez le focus dans un champ de texte d’une autre app.
2. Appuyez sur `Option+Space`.
3. Recherchez un mode de prompt par correspondance approximative (par exemple, `res` peut trouver `Résumer`), utilisez `Up` / `Down` pour le mettre en évidence, puis appuyez sur `Tab` ou `Enter` pour valider le mode.
4. Tapez ou collez votre texte brut.
5. Appuyez sur `Enter` pour le transformer. Le résultat s’affiche au fur et à mesure de sa génération ; appuyez sur `Escape` pour l’arrêter.
6. Appuyez de nouveau sur `Enter` pour insérer le résultat, ou sur `Shift+Command+C` (ou cliquez sur le bouton de copie du résultat) pour le copier.

Avec la dictée :

1. **Ouvrez l’Assistant de rédaction** avec `Option+Space`.
2. **Validez un mode de prompt**. La dictée n’est pas disponible dans le sélecteur de modes ni dans l’éditeur de résultat.
3. **Placez le curseur dans le brouillon source, ou sélectionnez le texte à remplacer.** La dictée s’insère au curseur ou remplace la sélection.
4. **Maintenez le raccourci de dictée configuré** (Option droite par défaut) et parlez normalement pendant que le brouillon se met à jour sur place. Un appui bref ne fait rien. Si la connexion en temps réel échoue, continuez à maintenir et à parler pendant qu’Inklet conserve un enregistrement temporaire de récupération.
5. **Relâchez pour finaliser** la transcription. Avec **Sur ce Mac**, la récupération transcrit l’enregistrement sur votre Mac. Avec OpenAI, si une récupération est nécessaire, Inklet envoie une seule requête à `https://api.openai.com/v1/audio/transcriptions` avec la même clé d’API OpenAI existante que celle utilisée par la dictée en temps réel. L’enregistrement temporaire reste local jusqu’au démarrage effectif de la requête de repli, il est téléversé au plus une fois et supprimé à la fin de la session.
6. Relisez et modifiez le brouillon dicté. La dictée seule n’exécute pas le mode de prompt et n’insère pas de texte dans une autre app.
7. **N’appuyez sur Return que lorsque vous êtes prêt** à exécuter le mode de prompt validé ; appuyez de nouveau sur Return uniquement pour insérer le résultat.

Le raccourci de dictée ne fonctionne que dans l’éditeur source et uniquement en le maintenant. Vous pouvez changer sa touche de modification pour Commande droite, Option gauche ou Commande gauche, ou désactiver complètement la dictée, dans **Réglages** → **Dictée en temps réel**. Escape, la perte du focus, la fermeture du popover ou l’ouverture d’une autre session source annulent la dictée et restaurent le brouillon d’origine.

## Fonctionnalités

- S’ouvre avec un raccourci global macOS. Par défaut : `Option+Space`.
- Diffuse la dictée en temps réel dans l’éditeur source actif de l’Assistant de rédaction tant qu’un raccourci de touche de modification est maintenu. Par défaut : Option droite.
- Affiche les actions de sélection lorsque vous sélectionnez du texte dans une autre app du Mac et marquez une courte pause, avec une lecture de la sélection façon EasyDict, une traduction rapide, un prompt **Traduire** personnalisable, une prononciation par IA, des résultats de traduction redimensionnables qui mémorisent leur dernière taille et un cache local de 7 jours pour les traductions répétées.
- Vous pouvez faire glisser la barre de sélection ou son résultat n’importe où s’ils masquent quelque chose ; les clics fonctionnent toujours et, à la sélection suivante, la barre réapparaît près du texte.
- Ignore les sélections de plus de 1 500 caractères pour éviter les déclenchements accidentels sur une page entière.
- Lit directement le texte sélectionné et peut lire, depuis le résultat de traduction, le texte original comme le texte traduit.
- Vous laisse choisir les boutons du menu de sélection et leur ordre, dans **Réglages** › **Assistant de sélection** › **Boutons du menu**. **Traduire**, **Prononcer** et n’importe quel mode de prompt peuvent devenir un bouton ; jusqu’à quatre s’affichent à la fois, les autres sont regroupés sous **Plus**. Un bouton de mode de prompt exécute ce mode sur le texte sélectionné et affiche le résultat dans le panneau avec des commandes de copie et de lecture.
- Transforme le texte avec des modes de prompt intégrés :
  - To Simple and Correct English (dans votre langue d’écriture, à choisir dans Réglages › Général ; anglais par défaut)
  - Summarize (dans votre langue de traduction, qui suit par défaut la langue de l’interface)
  - To French, To Japanese, etc. (traduit dans votre langue de traduction ; pour un seul mot, affiche son sens, sa prononciation et des phrases d’exemple)
  - Voice Cleanup
  - Les noms des modes intégrés restent en anglais dans toutes les langues de l’interface, pour que les mêmes lettres les retrouvent ; ils indiquent vos langues jusqu’à ce que vous les renommiez.
- Affiche le résultat dans le popover au fur et à mesure de sa génération, puis l’insère dans l’app qui avait le focus ou le copie avec le bouton de copie du résultat.
- Utilise un seul chemin de sélection, indépendant de l’app et fondé d’abord sur l’Accessibilité. Les actions de sélection automatiques demandent d’abord la sélection à l’Accessibilité de macOS, puis n’utilisent le repli configuré via un presse-papiers temporaire que si la **Sélection forcée** l’autorise. Chaque lecture reste liée au processus source capturé et s’annule si ce processus se termine ou perd le focus.
- Laisse le `Command+C` simulé désactivé par défaut. La copie par le menu reste le repli sûr de la **Sélection forcée** ; vous pouvez activer explicitement la copie simulée comme repli avancé pour les apps sans menu Copier utilisable, mais elle peut perturber les jeux, les bureaux à distance ou les machines virtuelles.
- Sérialise les lectures temporaires du presse-papiers et ne restaure l’instantané précédent que tant que la même lecture détient encore le résultat de copie observé ; le contenu le plus récent du presse-papiers l’emporte. Le déclenchement par double copie est passif : il utilise la copie que l’utilisateur a déjà faite, sans lancer d’autre copie synthétique ni restaurer de données plus anciennes. Le clic droit reste natif et ne lance jamais de lecture de la sélection.
- N’utilise aucun code de sélection propre aux navigateurs et ne demande pas l’autorisation Automatisation pour les navigateurs. Chrome, Safari, Edge et les apps natives empruntent le même chemin générique.
- Vous permet de modifier les modes de prompt, le fournisseur, le modèle, le point de terminaison personnalisé compatible OpenAI, le délai d’expiration, le raccourci d’écriture, le raccourci de dictée à maintenir, le micro, le modèle de récupération, la langue de traduction de la sélection, le prompt **Traduire** de la sélection, les boutons du menu de sélection, le mode **Sélection forcée**, l’autorisation de copie simulée, ainsi que la voix et la vitesse de la prononciation par IA.
- Affiche un **Historique** local des résultats d’écriture et de sélection réussis, avec regroupement des doublons consécutifs, texte source et résultat sélectionnables, une commande de copie du résultat et une action pour tout effacer. Les anciennes entrées Voice restent lisibles.
- Écrit et traduit avec OpenAI, Anthropic, Google Gemini, DeepSeek, Alibaba Qwen, Moonshot Kimi, Zhipu GLM, MiniMax, SiliconFlow, Volcengine Ark, Tencent Hunyuan, Baichuan, 01.AI Yi, xAI, Groq, Mistral, OpenRouter, Perplexity, Together AI, Cerebras ou tout point de terminaison personnalisé compatible OpenAI, comme un serveur de modèles local. La prononciation utilise toujours OpenAI ; la dictée utilise le moteur de reconnaissance vocale choisi dans **Dictée en temps réel**.
- Exécute l’écriture et la traduction sur votre Mac avec le moteur intégré (Qwen3.5 4B ou Gemma 4 E4B, téléchargés une seule fois depuis Hugging Face), ou avec un serveur Ollama ou LM Studio local. Aucune clé d’API n’est nécessaire et le texte reste sur votre Mac.
- Propose l’interface de l’app en anglais, chinois simplifié, chinois traditionnel, japonais, coréen, espagnol, français, allemand, portugais et italien.
- Adapte les menus de sélection compacts et les commandes à l’espace restreint des réglages et de l’écriture aux libellés traduits ; changer de langue rafraîchit l’interface ouverte tout en conservant le texte en cours.

## État actuel

Inklet est un MVP à un stade précoce. Le dépôt contient actuellement :

- Un Swift Package pour l’app macOS et le moteur d’écriture principal.
- Une app de barre des menus avec un popover d’écriture et une fenêtre de réglages.
- Des adaptateurs de fournisseurs et le stockage de la configuration.
- Des tests unitaires du comportement principal.
- Des notes de test manuel dans [docs/manual-test-checklist.md](docs/manual-test-checklist.md).

## Prérequis

- macOS 14 ou version ultérieure.
- Toolchain Swift 6.
- Xcode complet est recommandé pour la prise en charge de XCTest.
- L’autorisation Accessibilité pour Inklet, nécessaire à la lecture générique de la sélection, au repli par copie configuré, au retour du focus vers l’app précédente et au collage du résultat généré.
- L’autorisation Microphone pour la dictée en temps réel pendant le maintien du raccourci.
- Une clé d’API OpenAI ou d’un autre fournisseur pris en charge, ou un modèle local. La prononciation, ainsi que la dictée avec le moteur OpenAI, nécessitent une clé d’API OpenAI.

## Modèles locaux

Inklet peut écrire et traduire avec un modèle qui s’exécute sur votre Mac : votre texte ne le quitte jamais et aucune clé d’API n’est nécessaire.

- **Intégré** (puce Apple uniquement, et choix par défaut des nouvelles installations) : choisissez **Intégré** comme fournisseur, sélectionnez un modèle et cliquez sur **Télécharger**. Gemma 4 E4B (environ 4,6 Go) est le modèle par défaut sur les Mac dotés de 16 Go de mémoire ou plus ; Qwen3.5 4B (environ 2,7 Go) est recommandé pour 8 Go. Lors d’une nouvelle installation, le guide de bienvenue le télécharge ; pendant le téléchargement, le popover d’écriture affiche la progression, avec un bouton **Télécharger** si le modèle n’est pas encore là. Les téléchargements reprennent après une interruption et sont vérifiés avec un SHA-256 épinglé avant utilisation. Quand vous ouvrez le popover d’écriture avec **Intégré** sélectionné, Inklet démarre son serveur llama.cpp intégré uniquement sur l’adresse de bouclage et charge le modèle, qui est donc généralement prêt au moment où vous envoyez votre texte. Sur les Mac dotés de 24 Go de mémoire ou plus, le modèle reste chargé et n’est libéré que lorsque macOS manque de mémoire ; sur les Mac plus modestes, le serveur le libère après cinq minutes d’inactivité.
- **Dictée sur ce Mac** (puce Apple uniquement, et choix par défaut des nouvelles installations) : la Dictée en temps réel reconnaît la parole avec Qwen3-ASR 0.6B (environ 1 Go), qui comprend 30 langues ainsi que le chinois mêlé d’anglais. Elle tourne sur le même moteur llama.cpp intégré, dans un serveur distinct, retranscrit ce que vous dites environ toutes les 0,6 seconde pendant que vous parlez et fige chaque phrase à chaque pause. Sur les Mac dotés de 16 Go de mémoire ou plus, le modèle vocal reste chargé tant que la dictée est activée ; sur les Mac plus modestes, il se charge à l’ouverture du popover d’écriture et se libère après cinq minutes d’inactivité. Désactiver la dictée, ou choisir OpenAI, l’arrête. Quand Inklet ou macOS utilise le chinois traditionnel, la dictée en chinois s’écrit en caractères traditionnels.
- **Ollama** : installez [Ollama](https://ollama.com), exécutez `ollama pull qwen3.5:4b`, puis choisissez **Ollama**. Inklet liste les modèles qu’Ollama a téléchargés.
- **LM Studio** : démarrez le serveur local de LM Studio sur le port 1234, chargez un modèle, puis choisissez **LM Studio**.

Les fournisseurs locaux disposent d’au moins 120 secondes par requête pour que la première requête puisse charger le modèle. Inklet demande aux serveurs locaux de sauter la « réflexion » afin que les petits modèles de raisonnement répondent directement. Les versions compilées depuis les sources construisent le moteur intégré avec `scripts/build-llama-server.sh`, qui nécessite `cmake` ; s’il manque, l’app fonctionne quand même et l’option **Intégré** indique que le moteur n’est pas inclus.

## Compiler et exécuter

Avant chaque compilation du bundle de l’app, augmentez à la fois `INKLET_VERSION` et `INKLET_BUILD_NUMBER` dans le fichier `VERSION` à la racine. Incrémentez normalement la version de correctif ; utilisez une version mineure ou majeure pour les changements plus importants. Le numéro de build doit rester un entier positif supérieur à tous les numéros de build déjà utilisés, y compris d’une version commerciale à l’autre. Vérifiez la dernière `main`, les tags Git, toutes les versions GitHub (brouillons compris) et les worktrees actifs avant de le choisir. Inklet se fonde uniquement sur ce numéro de build pour savoir si une mise à jour est plus récente.

Ne lancez les compilations distantes du DMG sur GitHub que depuis `main`, après avoir fusionné et poussé les changements prévus et le `VERSION` mis à jour. Déclenchez `build-dmg.yml` avec `--ref main`.

Pour une version officielle, vérifiez la réussite de la compilation et les fichiers finaux, remplacez la description provisoire par les changements en chinois et en anglais depuis la précédente version stable publiée, puis publiez-la comme dernière version stable. Un brouillon déjà vérifié peut être publié sans recompilation ni changement de version.

Le workflow du DMG vérifie avant la compilation que le numéro de build n’est ni réutilisé ni inférieur ; il n’incrémente aucune des deux valeurs automatiquement. Voir [release version checks](scripts/README.md#release-version-checks) pour la validation manuelle. Changer la version d’une app empaquetée nécessite de recompiler, signer, notarier et régénérer les sommes de contrôle ; changer uniquement le titre de la version ou le nom du fichier ne met pas l’app à jour.

À la racine du dépôt :

```bash
swift build
scripts/run-local-app.sh
```

Utilisez `scripts/run-local-app.sh` pour les tests manuels courants depuis n’importe quel worktree. Il installe et ouvre l’identité stable `/Applications/Inklet Local.app`, afin que les autorisations Accessibilité et trousseau de macOS soient réutilisées d’une compilation à l’autre.

Lancer les tests :

```bash
swift test
```

Si les tests échouent parce que `XCTest` n’est pas disponible, installez l’app Xcode complète plutôt que les seuls Command Line Tools.

Vérifiez toutes les langues de l’interface avec `scripts/check-localization.sh`. Ajoutez `--snapshots` pour générer une galerie HTML locale de vues natives synthétiques dans `.build/localization-audit/` ; la commande en affiche le chemin. Les pull requests et les pushes sur `main` exécutent automatiquement l’ensemble des tests unitaires et les vérifications de localisation. Voir [localization audit](docs/localization-audit.md) pour la couverture et les vérifications manuelles restantes.

## Raccourcis clavier

- `Option+Space` : ouvre le popover d’écriture.
- `Right Option` : maintenez pour dicter lorsque l’éditeur source de l’Assistant de rédaction est actif. Changez la touche de modification ou désactivez la dictée dans **Réglages** → **Dictée en temps réel** ; un appui bref reste sans effet.
- `Up` / `Down` dans le lanceur de modes : déplace la mise en évidence parmi les modes de prompt classés par correspondance approximative.
- `Tab`, `Return` ou `Enter` du pavé numérique dans le lanceur de modes : valide le mode de prompt mis en évidence et place le focus dans l’éditeur source. Pendant une composition de saisie, Return sert toujours à valider le texte ou un candidat ; Return avec Commande, Maj, Option ou Contrôle ne valide pas de mode.
- `Enter` dans l’éditeur : transforme le texte source, insère un résultat généré par le mode actuel, ou régénère avec le mode tout juste validé un résultat obsolète issu d’un mode précédent.
- `Command+Enter` : insère le texte original sans appeler le modèle.
- `Shift+Command+C` : copie le résultat visible sans fermer le popover.
- `Command+Up` / `Command+Down` : parcourt les modes de prompt visibles.
- Maintenir `Command` seule : affiche tous les raccourcis dans la barre d'actions. Sinon, la barre n'affiche que l'indication de dictée et le bouton principal ; tous les raccourcis fonctionnent dans les deux cas.
- `Escape` : recule d’un niveau à chaque appui, du résultat à l’éditeur source, puis au lanceur de modes, puis ferme le popover. Pendant une transformation, arrête la génération, abandonne le résultat partiel et reste dans l’éditeur.
- `Command+,` : ouvre les réglages lorsque Inklet est actif.

La recherche ignore la casse et les accents et prend en charge la correspondance de caractères dans l’ordre. Les correspondances exactes et de préfixe sont les plus favorisées ; les correspondances consécutives, en début de mot, plus précoces et plus serrées se classent généralement plus haut.

À l’ouverture du lanceur de modes, le dernier mode de prompt validé est mis en évidence s’il est encore visible. Un clic met un mode en évidence ; un double-clic le valide. Revenir au lanceur conserve le brouillon et le résultat en cours.

## Organisation du dépôt

```text
Sources/InkletApp/       macOS app, popover UI, settings UI, menu bar coordination
Sources/InkletCore/      core config, providers, prompts, hotkeys, insertion, state machine
Tests/InkletCoreTests/   unit tests for core behavior
docs/                    QA manuelle et politique de confidentialité
```

## Notes de développement

- Gardez le comportement des fournisseurs couvert par des tests unitaires ciblés.
- Utilisez [docs/manual-test-checklist.md](docs/manual-test-checklist.md) avant de publier des changements visibles par les utilisateurs.
- Utilisez `scripts/run-local-app.sh` plutôt qu’un exécutable SwiftPM brut ou `open dist/...` pour les tests manuels courants, afin que les autorisations locales d’Accessibilité et du trousseau restent attachées à une seule identité d’app stable.
- Traitez avec soin les flux du presse-papiers et d’Accessibilité ; ils sont au cœur de l’expérience de l’app.
- Le projet est encore au stade de MVP : le README doit suivre le code plutôt que les projets futurs.

## Stockage local et mises à niveau

Les versions de production et de QA locale utilisent un stockage propre à chaque bundle et ne partagent ni réglages, ni Historique, ni cache de traduction, ni diagnostics, ni identifiants du trousseau :

- Application Support de production : `~/Library/Application Support/com.tomwan.inklet/`
- Application Support locale : `~/Library/Application Support/com.tomwan.inklet.local/`
- Préférences de production : `~/Library/Preferences/com.tomwan.inklet.plist`
- Préférences locales : `~/Library/Preferences/com.tomwan.inklet.local.plist`
- Clés d’API des fournisseurs : `api-keys.json` dans le dossier Application Support correspondant, lisible uniquement par votre compte utilisateur et exclu des sauvegardes Time Machine
- Services du trousseau utilisés par les versions précédentes : `Inklet.ProviderAPIKey` (production) et `Inklet.Local.ProviderAPIKey` (local)

Les versions précédentes conservaient les clés d’API dans le trousseau. La première fois qu’une clé est nécessaire, Inklet la copie du trousseau vers `api-keys.json` et laisse l’élément du trousseau en place, si bien qu’un retour à une version précédente la retrouve toujours. Modifier ou effacer une clé dans les réglages supprime la copie du trousseau.

Au premier lancement après une mise à niveau depuis l’ancienne version en sandbox, Inklet copie automatiquement les anciennes préférences reconnues, les clés d’API des fournisseurs vers le service de trousseau correspondant et l’Historique vers le stockage du bundle actuel. Il ne supprime ni ne modifie la source ancienne : les anciennes données restent disponibles pour un retour en arrière ou une récupération. Le cache de traduction, jetable, n’est pas migré.

Si macOS bloque l’accès automatique à l’ancien conteneur correspondant, les réglages gardent disponible l’action **Importer les données**. L’import assisté valide le dossier `Data` ancien exact du bundle de production ou local en cours d’exécution, ne le lit que tant que l’autorisation actuelle du panneau de fichiers est valide et n’enregistre aucun signet d’accès persistant.

## Confidentialité

- Inklet envoie les requêtes d’écriture et de traduction de la sélection au fournisseur choisi dans les réglages, avec la clé d’API de ce fournisseur. La prononciation utilise toujours votre clé d’API OpenAI et OpenAI. La dictée n’utilise OpenAI que si vous le choisissez comme moteur de reconnaissance vocale.
- Avec la reconnaissance vocale **Sur ce Mac**, l’audio de la dictée et son enregistrement de récupération sont traités par un serveur sur votre Mac et ne le quittent jamais.
- Avec la reconnaissance vocale OpenAI, pendant que vous maintenez le raccourci de dictée, l’audio du micro actif est diffusé directement vers la transcription OpenAI Realtime. Inklet conserve aussi un enregistrement local temporaire de récupération. Il reste local jusqu’au démarrage effectif de la requête de repli, est téléversé au plus une fois vers `https://api.openai.com/v1/audio/transcriptions` avec la même clé d’API OpenAI existante que celle utilisée par la dictée en temps réel, et il est supprimé quelle que soit la façon dont la session se termine.
- Vos clés d’API sont stockées localement sur votre Mac, une par fournisseur.
- Avec les fournisseurs **Intégré**, Ollama ou LM Studio, les requêtes d’écriture et de traduction ne vont qu’à un serveur sur votre Mac. Le téléchargement d’un modèle intégré envoie une requête à Hugging Face pour le fichier choisi ; elle ne contient ni votre texte, ni votre audio, ni vos clés d’API, ni vos réglages.
- Inklet utilise l’autorisation Accessibilité pour la lecture générique de la sélection, le repli par copie configuré, le retour du focus vers l’app précédente et le collage du texte.
- Inklet n’utilise l’autorisation Microphone que pendant un maintien valide du raccourci de dictée dans l’éditeur source actif de l’Assistant de rédaction. À la fin de la dictée, il reste un brouillon modifiable, et rien n’est inséré dans une autre app.
- Inklet utilise temporairement le presse-papiers pour l’insertion et pour les lectures de repli de **Sélection forcée** configurées. Une lecture de **Sélection forcée** ne restaure le presse-papiers précédent que si la valeur copiée temporairement par Inklet est toujours actuelle, et n’écrase pas une modification externe ultérieure du presse-papiers.
- Inklet enregistre localement dans l’Historique le texte source et le résultat des actions d’écriture et de sélection réussies jusqu’à ce que vous l’effaciez dans les réglages, en ignorant les doublons consécutifs. Un brouillon dicté non traité ne crée aucune entrée d’Historique ; les anciennes entrées Voice restent lisibles localement.
- Les actions de sélection capturent l’app source et l’emplacement de la sélection, valident cette source avant et pendant la lecture, et utilisent l’Accessibilité pour lire sa sélection actuelle. Si l’Accessibilité ne renvoie pas le texte sélectionné, le mode **Sélection forcée** configuré peut brièvement invoquer Copier dans le menu et lire le texte obtenu dans le presse-papiers via la transaction protégée décrite ci-dessus. Le `Command+C` simulé est désactivé par défaut et ne s’exécute qu’après une activation avancée explicite. Vous pouvez désactiver la **Sélection forcée** dans les réglages. Ce chemin n’envoie aucun Apple Event ciblant un navigateur et ne demande pas l’autorisation Automatisation pour les navigateurs. Appuyer deux fois rapidement sur `Command+C` après avoir sélectionné du texte lit explicitement la copie que vous avez déjà faite. Inklet n’enregistre pas un texte simplement sélectionné, sauf si une action réussie est consignée dans l’Historique local.
- L’Assistant de sélection met en cache localement pendant 7 jours les traductions réussies, avec des clés de cache hachées, pour accélérer les traductions répétées.
- Lorsqu’aucune traduction n’est disponible dans le cache local, la traduction de l’Assistant de sélection envoie le texte sélectionné et vos instructions **Traduire** personnalisées au fournisseur choisi ; un bouton de mode de prompt envoie le texte sélectionné et le prompt de ce mode au fournisseur choisi ; la prononciation par IA envoie le texte sélectionné à OpenAI.
- Inklet récupère le catalogue public de modèles sur `models.dev` au plus une fois par jour. Cette requête ne contient ni votre texte, ni votre audio, ni vos clés d’API, ni les réglages de l’app.
- N’envoyez pas de texte ou d’audio privés à OpenAI ou au fournisseur choisi si vous ne faites pas confiance à leurs politiques de traitement des données.

## Commentaires

Choisissez **Envoyer un commentaire…** dans le menu d’Inklet de la barre des menus, ou [ouvrez une issue](https://github.com/wanming/Inklet/issues/new/choose). Les signalements de bugs et les idées de fonctionnalités sont les bienvenus ; ne collez jamais de clé d’API ni de texte privé dans une issue.

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md).

## Sécurité

Voir [SECURITY.md](SECURITY.md) pour le signalement des vulnérabilités et les consignes sur les données sensibles.

## Licence

Inklet est publié sous [MIT License](LICENSE).
Les mentions relatives aux tiers figurent dans [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
