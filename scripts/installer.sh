#!/bin/zsh
# Compile Dictée, fabrique Dictée.app et l'installe dans /Applications.
set -e
cd "${0:A:h}/.."
APP="build/Dictée.app"
swift build -c release
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Dictee "$APP/Contents/MacOS/Dictee"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Icône
swift scripts/icone.swift build/AppIcon.iconset >/dev/null
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
# Signature stable (certificat local, voir scripts/certificat.sh) : macOS garde les autorisations d'une version à l'autre.
KC="$PWD/.signature/dictee.keychain-db"
[[ -f "$KC" ]] || ./scripts/certificat.sh
security unlock-keychain -p "$(cat .signature/mot-de-passe)" "$KC"
# codesign ne trouve le certificat que si son trousseau est dans la liste de recherche
if ! security list-keychains -d user | grep -q "dictee.keychain-db"; then
  security list-keychains -d user -s $(security list-keychains -d user | tr -d '"' | xargs) "$KC"
fi
codesign --force --deep --sign "Dictee local" "$APP"
# Whisper (le moteur de transcription, gratuit, tourne sur le Mac) : installé par Homebrew s'il manque
if [[ ! -x /opt/homebrew/bin/whisper-server && ! -x /usr/local/bin/whisper-server ]]; then
  if ! command -v brew >/dev/null; then
    echo "Homebrew manque : installe-le depuis https://brew.sh puis relance ce script." >&2; exit 1
  fi
  brew install whisper-cpp
fi
# Modèle Whisper : téléchargé une fois (16 Go de mémoire ou plus : le complet, sinon le compressé)
SUPPORT="$HOME/Library/Application Support/Dictee"
mkdir -p "$SUPPORT"
if [[ ! -f "$SUPPORT/ggml-large-v3-turbo.bin" && ! -f "$SUPPORT/ggml-large-v3-turbo-q5_0.bin" ]]; then
  if [[ -n "$DICTEE_MODELE" && -f "$DICTEE_MODELE" ]]; then
    ln "$DICTEE_MODELE" "$SUPPORT/ggml-large-v3-turbo.bin" 2>/dev/null || cp "$DICTEE_MODELE" "$SUPPORT/ggml-large-v3-turbo.bin"
  else
    if (( $(sysctl -n hw.memsize) >= 16000000000 )); then NOM="ggml-large-v3-turbo.bin"; else NOM="ggml-large-v3-turbo-q5_0.bin"; fi
    echo "Téléchargement du modèle $NOM (une seule fois, de 0,5 à 1,6 Go)…"
    curl -L --fail --progress-bar -o "$SUPPORT/$NOM.part" "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$NOM"
    mv "$SUPPORT/$NOM.part" "$SUPPORT/$NOM"
  fi
fi
# Remplacer l'ancienne version
pkill -x Dictee 2>/dev/null || true
sleep 0.5
pkill -f "whisper-server .*--port 8178" 2>/dev/null || true   # pas de serveur Whisper orphelin
rm -rf "/Applications/Dictée.app"
cp -R "$APP" "/Applications/Dictée.app"
echo "Installé : /Applications/Dictée.app"
