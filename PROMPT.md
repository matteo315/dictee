# Prompt : ta propre dictée vocale gratuite sur Mac (alternative locale à Wispr Flow)

> **Mode d'emploi.** Ouvre Claude Code dans un dossier vide (par exemple `~/Dictée`) et colle tout ce qui suit la ligne « ---- ».
> Claude Code va te poser 3 questions, construire l'appli, l'installer, puis te guider pour les autorisations.
> Il te faut un Mac avec une puce Apple (M1 ou plus récent), macOS 14 ou plus, et environ 3 Go de libre.
> Gratuit : rien n'est envoyé sur internet, ta voix reste sur ton Mac.

----

Tu vas construire et installer sur mon Mac une appli de dictée vocale appelée **Dictée** : un équivalent gratuit et 100 % local de Wispr Flow. Je ne suis pas forcément développeur : parle-moi simplement, explique chaque terme technique la première fois, et fais tout le travail toi-même. Je ne fais que ce que macOS m'oblige à faire de mes mains (les autorisations).

Le code de référence existe et est open source : **https://github.com/matteo315/dictee**. Commence par lui (étape 2). La description complète plus bas sert à le reconstruire à l'identique s'il est inaccessible, ou à corriger ce qui casse.

## Étape 0 — Trois questions avant de commencer

Pose-moi ces questions en une seule fois. Propose la réponse par défaut pour chacune, que je peux juste valider :

1. **Langue de dictée** : français (par défaut), anglais, espagnol, allemand, italien, portugais, ou détection automatique.
2. **Touche de dictée** : Ctrl (par défaut), Maj, Option droite ou Cmd droite. On appuie deux fois pour parler, une fois pour coller le texte. Échap annule. Explique-moi pourquoi on n'utilise pas fn : sur les Mac récents, fn ouvre le panneau des emojis.
3. **Mots à bien écrire** : quels noms reviennent souvent dans ce que j'écris (mon entreprise, mes clients, mes outils) ? Tu les mets dans le dictionnaire de départ. Par défaut : Claude, ChatGPT, Wispr Flow.

## Étape 1 — Vérifier le Mac (sans rien casser)

- Puce Apple : `uname -m` doit dire `arm64`. Sur un Mac Intel, préviens-moi que ce sera lent et demande si on continue.
- macOS 14 ou plus : `sw_vers -productVersion`.
- Outils de compilation d'Apple : `xcode-select -p`. S'ils manquent, lance `xcode-select --install` et attends que j'aie cliqué sur « Installer ».
- Homebrew (le gestionnaire d'outils gratuit du Mac) : `brew --version`. S'il manque, donne-moi la commande officielle de https://brew.sh à coller moi-même dans le Terminal, car elle demande mon mot de passe. Tu ne tapes jamais mon mot de passe.
- Si Wispr Flow tourne, demande-moi de le quitter : deux applis qui écoutent la même touche se gênent.

## Étape 2 — Récupérer et installer

1. `git clone https://github.com/matteo315/dictee.git .` dans le dossier courant.
2. Applique mes réponses de l'étape 0 :
   - la langue : `language` dans les réglages par défaut (`Reglages` dans `Sources/Dictee/Store.swift`) ;
   - la touche : `touche` ;
   - mes mots : `defaultDictionary`.
   Garde le reste tel quel. Je peux aussi tout changer plus tard dans l'appli, page Réglages.
3. Lance `./scripts/installer.sh`. Il fait tout seul :
   - il compile l'appli ;
   - il fabrique `Dictée.app` avec son icône ;
   - il crée un certificat local pour signer l'appli (voir « Pièges », point 1) ;
   - il installe Whisper avec Homebrew (`brew install whisper-cpp`) ;
   - il télécharge une seule fois le modèle de transcription : `ggml-large-v3-turbo.bin` (1,6 Go) si le Mac a 16 Go de mémoire ou plus, sinon `ggml-large-v3-turbo-q5_0.bin` (0,5 Go). Il vient de huggingface.co/ggerganov/whisper.cpp et se range dans `~/Library/Application Support/Dictee/` ;
   - il copie l'appli dans `/Applications/Dictée.app`.
4. Lance les tests : `./scripts/tester.sh`. Il faut 9 réussis sur 9.
5. Ouvre l'appli : `open /Applications/Dictée.app`.

Si une étape échoue, lis l'erreur, corrige en t'appuyant sur la description complète ci-dessous, et recommence. Ne contourne jamais une erreur en désactivant une protection de macOS.

## Étape 3 — Me guider pour les autorisations (je les fais moi-même)

macOS exige que ce soit moi qui clique. Explique-moi chaque autorisation en une phrase, une par une, puis attends que je te dise « c'est fait ». Ouvre-moi le bon panneau avec `open "x-apple.systempreferences:com.apple.preference.security?Privacy_…"` :

1. **Micro** (`Privacy_Microphone`) : pour entendre ma voix. La fenêtre de demande apparaît toute seule à la première dictée, je clique « Autoriser ».
2. **Accessibilité** (`Privacy_Accessibility`) : pour coller le texte là où est mon curseur et pour entendre la touche de dictée. J'active « Dictée » dans la liste.
3. **Surveillance de la saisie** (`Privacy_ListenEvent`) : pour entendre la touche de dictée dans toutes les applis. J'active « Dictée ».

Ensuite, quitte et rouvre l'appli : `pkill -x Dictee; open /Applications/Dictée.app`.

**Si l'appli dit « pas autorisé » alors que l'interrupteur est bleu**, c'est une ancienne entrée restée en mémoire. Je sélectionne Dictée dans la liste, je clique sur « − » pour la retirer, puis sur « + » pour la rajouter depuis /Applications. Décocher puis recocher ne suffit pas.

## Étape 4 — Le premier essai, avec moi

Fais-moi faire ce test et attends mon retour :

1. J'ouvre Notes, je clique dans une note.
2. J'appuie deux fois vite sur ma touche. Une petite pastille noire apparaît sur le bord gauche de l'écran, avec l'onde de ma voix.
3. Je dis : « Euh, bonjour, ceci est un essai de dictée avec Claude. »
4. J'appuie une fois sur ma touche. Moins de 2 secondes après, le texte apparaît, sans le « euh ».
5. J'ouvre Dictée depuis l'icône en forme d'onde en haut de l'écran : la dictée est dans l'historique et dans les statistiques.

Si rien ne se passe, regarde `~/Library/Application Support/Dictee/whisper.log` et la page Réglages de l'appli (les autorisations y sont affichées en direct).

## Étape 5 — Me dire ce que j'ai

Termine par un résumé court, en français simple :
- les raccourcis ;
- où sont mes données : `~/Library/Application Support/Dictee` (historique, dictionnaire, réglages ; jamais l'audio) ;
- comment mettre à jour : `git pull && ./scripts/installer.sh`. Les autorisations restent ;
- comment désinstaller :
  - supprimer `/Applications/Dictée.app` et `~/Library/Application Support/Dictee` ;
  - retirer Dictée des autorisations ;
  - si je veux, `brew uninstall whisper-cpp`.
- L'appli s'ouvre toute seule au démarrage du Mac. Je peux couper ça dans Réglages.

---

# Description complète de l'appli (pour la reconstruire à l'identique)

## Ce que fait l'appli

- **Une barre sur le bord gauche de l'écran**, au milieu en hauteur, sur l'écran où se trouve la souris (elle suit la souris d'un écran à l'autre, vérifié toutes les 0,3 s).
  - Au repos : un trait noir arrondi de 5 × 44 points.
  - Souris dessus : un bouton micro noir de 40 × 40 (coins de 12) et une capsule noire « Dicter ⌃ ⌃ » (le symbole suit la touche choisie).
  - Clic sur le micro : la dictée commence en mains libres.
- **Pendant la dictée**, une petite pastille noire haute de 26 points :
  - un bouton Annuler (croix) et un bouton Terminer, ronds, de 18 points ;
  - entre les deux, une onde de 14 barres blanches larges de 2, hautes de 2 + niveau × 12.
  - Pendant la transcription : une petite roue de chargement, puis la pastille se replie.
- **Raccourcis**, partout sur le Mac :
  - deux appuis brefs sur la touche, en moins de 0,35 s : on commence ;
  - un appui : on finit, on transcrit et on colle ;
  - Échap : on annule (Échap est alors avalée, l'appli en dessous ne la reçoit pas).
  - Un seul appui ne démarre jamais le micro. Touche + autre touche (Ctrl+C…) ou touche + clic : ce n'est pas une dictée, le double appui est remis à zéro.
  - Un appui ne compte que s'il dure moins de 0,3 s.
- **Le texte est collé là où est le curseur**, dans l'appli qui était devant au début de la dictée. Le presse-papiers d'avant est remis en place 0,5 s après.
- **Nettoyage local**, sans IA :
  - on retire les hésitations : « euh », « heu », « hum », « hmm », « mmh », « bah euh », « ben euh », « bon euh » ;
  - on retire les annotations du type [Musique], (rires), *bruit* ;
  - on recolle les lignes que Whisper coupe au milieu des phrases ;
  - on remplace les mots du dictionnaire (en respectant les limites de mots, sans tenir compte des majuscules) ;
  - on corrige les espaces doubles et les virgules orphelines ;
  - on met une majuscule en début de phrase.
  - Les phrases que Whisper invente sur un silence (« Sous-titres réalisés par la communauté d'Amara.org », « Merci d'avoir regardé »…) donnent un texte vide : rien n'est collé.
- **Une dictée de moins de 0,3 s, ou silencieuse, est ignorée.** Silencieuse = aucune fenêtre de 0,1 s ne dépasse un niveau moyen (RMS) de 0,006.
- **Une icône en haut de l'écran** (symbole « waveform »), avec un menu : Ouvrir Dictée, Dicter en mains libres, Quitter Dictée.
- **Une fenêtre** (900 × 620, au moins 720 × 520) avec une barre latérale de 4 pages et, en bas de la barre, le rappel des raccourcis :
  - **Historique** :
    - les dictées groupées par jour, les plus récentes en haut ;
    - pour chacune : l'heure, l'appli où elle a été collée, le texte ;
    - un bouton Copier au survol, « Supprimer » au clic droit ;
    - une recherche par mot ;
    - si l'historique est vide, une phrase explique quoi faire.
  - **Statistiques**, en phrases plutôt qu'en cases :
    - mots dictés au total et ce mois-ci ;
    - vitesse moyenne (mots ÷ minutes parlées) ;
    - temps gagné : mots ÷ vitesse au clavier, moins le temps parlé. La vitesse au clavier vaut 40 mots/min par défaut et se règle ;
    - jours d'affilée (aujourd'hui compris, ou à partir d'hier si rien aujourd'hui) et meilleure série ;
    - une grille des 20 dernières semaines (un carré par jour, plus foncé quand on a plus dicté) ;
    - les applis où l'on dicte le plus, en barres.
  - **Dictionnaire** : la liste des noms à bien écrire. Chaque ligne donne la bonne écriture et ce que Whisper entend parfois à la place. On peut ajouter et supprimer.
  - **Réglages** :
    - Raccourcis : choix de la touche (Ctrl ⌃, Maj ⇧, Option droite ⌥, Cmd droite ⌘), deux appuis / un appui / Échap ;
    - Autorisations : Micro, Accessibilité, Surveillance de la saisie. L'état est relu toutes les 2 s, avec un bouton qui ouvre le bon panneau ;
    - Transcription : la langue (français, anglais, espagnol, allemand, italien, portugais, détection automatique ; changer de langue relance Whisper), le nom du modèle utilisé, la vitesse au clavier ;
    - Démarrage : un interrupteur « Ouvrir Dictée à l'allumage du Mac ».
  - La fenêtre s'ouvre toute seule au premier lancement, et quand l'autorisation Accessibilité manque.
- **Style** :
  - fond blanc, filets fins gris, texte noir, une seule couleur d'accent : le noir ;
  - pas de pastilles de couleur pour dire un état : les mots portent le sens ;
  - un champ montre son focus en fonçant son bord, jamais avec un anneau de couleur ;
  - les boutons rétrécissent légèrement quand on appuie (échelle 0,96).
- **Ouverture au démarrage du Mac** activée d'office au premier lancement, une seule fois (`SMAppService.mainApp.register()`). Si la personne la coupe dans Réglages, on ne la remet pas.
- **Tout en français** dans l'interface.

## Ce qu'on ne fait pas

- Pas de compte, pas d'envoi sur internet (hors le téléchargement unique du modèle), pas de synchronisation, pas d'appli iPhone.
- Pas de réécriture par une IA.
- On ne garde pas l'audio, seulement le texte.

## Comment c'est construit

- **Swift** (le langage d'Apple), SwiftUI pour les écrans et AppKit pour la barre et les raccourcis, avec Swift Package Manager. Pas de projet Xcode.
  - `Package.swift` : `swift-tools-version:5.10` (mode Swift 5), plateforme `.macOS(.v14)`, une cible exécutable `Dictee` dans `Sources/Dictee`.
- **L'appli est un « accessoire »** : `LSUIElement = true` dans `Resources/Info.plist`. Pas d'icône dans le Dock ; elle bascule en appli normale tant que la fenêtre est ouverte, puis revient en accessoire.
  - `CFBundleIdentifier` : `fr.poeisis.dictee`. `CFBundleExecutable` : `Dictee`. `CFBundleIconFile` : `AppIcon`.
  - `NSMicrophoneUsageDescription` : « Dictée écoute ta voix pour la transcrire, sur ce Mac uniquement. »
- **Fichiers** (`Sources/Dictee/`) :
  - `main.swift` : `AppDelegate`.
    - Il lance Whisper, la barre, l'icône de menu, la demande de micro et les raccourcis. Si les raccourcis échouent, il réessaie toutes les 2 s et demande l'Accessibilité.
    - Il active l'ouverture au démarrage.
    - Le point d'entrée est enveloppé dans `MainActor.assumeIsolated { … app.run() }`.
  - `Store.swift` : les données, dans `~/Library/Application Support/Dictee/`.
    - `historique.jsonl` : une dictée par ligne (id, date, texte, texte brut, mots, secondes, appli, identifiant de l'appli).
    - `dictionnaire.json` et `reglages.json`. Les réglages se lisent avec `decodeIfPresent` : un champ ajouté plus tard ne fait pas perdre les autres.
    - Le calcul des statistiques.
    - Le texte d'amorce donné à Whisper : « Bonjour. Voici une dictée en français, bien ponctuée. Noms : … » avec les mots du dictionnaire. Il aide la ponctuation et l'orthographe des noms.
  - `Audio.swift` : enregistrement du micro avec `AVAudioEngine`, converti avec `AVAudioConverter` en 16 kHz mono (le format de Whisper). Le niveau de la voix sert à l'onde. Le fichier est un WAV 16 bits fabriqué en mémoire.
  - `Whisper.swift` : lance `whisper-server` (Homebrew, `/opt/homebrew/bin/whisper-server`).
    - Commande : `-m <modèle> -l <langue> --host 127.0.0.1 --port 8178`. Le journal va dans `whisper.log`. Le modèle reste chargé, donc c'est rapide : environ 0,6 s pour 5 s de voix sur un M5.
    - Envoi en `POST multipart/form-data` sur `/inference`, avec `response_format=json`, `temperature=0.0`, `language`, `prompt` et `file`.
    - Juste après l'ouverture, le modèle peut encore se charger : on réessaie 40 fois toutes les 0,5 s.
  - `Cleaner.swift` : le nettoyage décrit plus haut. Les expressions régulières utilisent des limites de mots Unicode (`(?<![\p{L}\p{N}])…(?![\p{L}\p{N}])`).
  - `Dictator.swift` : le chef d'orchestre.
    - Il transcrit par morceaux pendant qu'on parle : après 12 s de parole, à la première pause d'une demi-seconde (ou au-delà de 28 s sans pause), il envoie le morceau à Whisper, avec la fin du texte précédent comme amorce. À la fin, il ne reste que le dernier morceau à traiter : environ 1 s d'attente, même après 3 minutes de dictée. Si un morceau échoue, il retranscrit tout d'un coup.
    - Étapes : repos → écoute → transcription.
    - Il mémorise l'appli au premier plan au début de la dictée.
    - Il colle, puis ajoute la dictée à l'historique.
  - `System.swift` :
    - `HotkeyMonitor` : un `CGEventTap` sur la session (`.cgSessionEventTap`, `.headInsertEventTap`, `.defaultTap`) pour `flagsChanged`, `keyDown`, `leftMouseDown` et `rightMouseDown`. Si macOS coupe le tap (`tapDisabledByTimeout`), on le relance.
    - Les touches :

      | Touche | Codes | Bit « enfoncée » |
      | --- | --- | --- |
      | Ctrl | 59 / 62 | `0x40000` |
      | Maj | 56 / 60 | `0x20000` |
      | Option droite | 61 | `0x40` |
      | Cmd droite | 54 | `0x10` |

      Pour Option et Cmd, ce sont les bits propres au côté droit.
    - Échap a le code 53.
    - `Paster` : il met le texte dans le presse-papiers avec le type `org.nspasteboard.TransientType` (pour que les gestionnaires de presse-papiers l'ignorent). Il simule Cmd+V (touche 9) avec `CGEvent` posté sur `.cghidEventTap`. Il remet l'ancien contenu après 0,5 s, si personne ne l'a changé entre-temps.
    - `Permissions` : `AXIsProcessTrusted`, `CGPreflightListenEventAccess`, `AVCaptureDevice.authorizationStatus(for: .audio)`.
  - `Pill.swift` : la barre et la pastille.
    - C'est un `NSPanel` non activant (`.nonactivatingPanel`, `canBecomeKey = false`, niveau `.statusBar`, `collectionBehavior` `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`), pour ne jamais voler le curseur à l'appli où l'on écrit.
    - Il accepte le premier clic (`acceptsFirstMouse`), et le survol est suivi même quand l'appli n'est pas devant (`NSTrackingArea` avec `.activeAlways`).
    - Tailles : repliée 16 × 64, survol 150 × 64, dictée 132 × 40. Elle se colle au bord gauche de `visibleFrame` de l'écran de la souris.
  - `Views.swift` : la fenêtre et ses 4 pages.
- **Scripts** (`scripts/`) :
  - `installer.sh` : décrit à l'étape 2.
  - `certificat.sh` : crée une fois pour toutes un certificat auto-signé de signature de code, « Dictee local » (valable 20 ans, généré avec `/usr/bin/openssl`).
    - Il le range dans un trousseau à part, `.signature/dictee.keychain-db`, avec un mot de passe aléatoire dans `.signature/mot-de-passe` (dossier ignoré par git).
    - Il l'importe avec `-T /usr/bin/codesign` et `set-key-partition-list`, puis ajoute ce trousseau à la liste de recherche de l'utilisateur. Sinon codesign répond « no identity found ».
  - `icone.swift` : dessine l'icône (carré noir arrondi, onde blanche). `iconutil` la convertit en `.icns`.
  - `tester.sh` : compile et lance les 9 tests du nettoyage (`Tests/test-nettoyage.swift`).

## Pièges déjà rencontrés (ne pas les refaire)

1. **Les autorisations sautaient à chaque mise à jour.** Avec la signature « ad hoc » par défaut, l'empreinte change à chaque compilation et macOS ne reconnaît plus l'appli. Solution : le certificat local. Avec la même signature à chaque fois, les autorisations restent.
2. **fn ouvre les emojis** et le texte se collait dans leur barre de recherche. On n'utilise pas fn.
3. **Une seule pression ne doit jamais allumer le micro**, sinon il s'allumerait à chaque raccourci Ctrl.
4. **Whisper invente du texte sur un silence** : d'où le seuil de silence et la liste des phrases inventées.
5. **Whisper coupe ses lignes** (« et ça\n marche ») : d'où le recollage.
6. **Erreur de compilation « main actor-isolated initializer in a synchronous nonisolated context »** dans `main.swift` : envelopper le démarrage dans `MainActor.assumeIsolated`.
7. **Ne jamais retirer « merci à tous » des dictées** : c'est une vraie phrase, pas une invention de Whisper.
8. Le premier lancement après l'installation peut prendre quelques secondes, le temps de charger le modèle. Le réessai de 20 s le couvre.

## Règles pour toi, Claude Code

- Tu ne tapes jamais un mot de passe et tu ne changes aucun réglage de sécurité à ma place.
- Tu ne désactives aucune protection de macOS (Gatekeeper, SIP, quarantaine).
- Tu n'envoies rien en ligne. Le seul téléchargement est le modèle Whisper.
- Avant de me dire « c'est fini », tu vérifies trois choses : les 9 tests sont verts, l'appli tourne (`pgrep -x Dictee`), et Whisper répond (`whisper.log` dit que le modèle est chargé). Tu me dis aussi honnêtement ce que tu n'as pas pu vérifier, par exemple la vraie dictée au clavier, que je dois faire moi-même.
