# Dictée

Une dictée vocale gratuite pour Mac, qui fonctionne entièrement sur l'ordinateur. C'est une alternative à Wispr Flow.

Tu parles, et le texte arrive là où est ton curseur, dans n'importe quelle appli. La transcription tourne sur ton Mac avec [Whisper](https://github.com/ggerganov/whisper.cpp), sans compte ni abonnement. Ta voix ne quitte jamais l'ordinateur.

- **Deux appuis** sur Ctrl : tu commences à parler. La touche se change dans Réglages : Maj, Option droite ou Cmd droite.
- **Un appui** : le texte est transcrit, nettoyé (sans les « euh ») et collé.
- **Échap** : tu annules.
- Une petite barre noire sur le bord de l'écran, qui suit la souris d'un écran à l'autre.
- Une fenêtre avec quatre pages :
  - **Historique** ;
  - **Statistiques** (mots dictés, vitesse, jours d'affilée, temps gagné) ;
  - **Dictionnaire** (les noms à bien écrire) ;
  - **Réglages**.
- Français, anglais, espagnol, allemand, italien, portugais, ou détection automatique.

## Installer avec Claude Code (le plus simple)

Ouvre Claude Code dans un dossier vide et colle le contenu de [PROMPT.md](PROMPT.md). Claude Code te pose trois questions, installe tout, puis te guide pour les autorisations.

## Installer à la main

Il te faut un Mac avec une puce Apple, macOS 14 ou plus récent, les outils de compilation d'Apple (`xcode-select --install`) et [Homebrew](https://brew.sh).

```bash
git clone https://github.com/matteo315/dictee.git && cd dictee
```

```bash
./scripts/installer.sh
```

```bash
open /Applications/Dictée.app
```

Le script installe `whisper-cpp` avec Homebrew. Il télécharge aussi une fois le modèle `large-v3-turbo` : 1,6 Go, ou 0,5 Go dans sa version compressée si le Mac a moins de 16 Go de mémoire. Ensuite, il signe l'appli avec un certificat local, pour que macOS garde tes autorisations d'une mise à jour à l'autre.

Ensuite, dans Réglages Système › Confidentialité et sécurité, autorise Dictée pour :
- **Micro** ;
- **Accessibilité** ;
- **Surveillance de la saisie**.

Si une autorisation reste « pas autorisé » alors que l'interrupteur est bleu : retire Dictée avec « − », puis rajoute-la avec « + ».

Pour mettre à jour : `git pull && ./scripts/installer.sh`.

Tes données sont dans `~/Library/Application Support/Dictee` : historique, dictionnaire et réglages. L'audio n'est jamais gardé.

## Licence

MIT.
