#!/bin/zsh
# Crée une fois pour toutes le certificat local qui signe Dictée.
# Même signature à chaque mise à jour = macOS garde les autorisations (micro, Accessibilité).
# Rangé dans un trousseau à part (.signature/), pas dans le trousseau de session.
set -e
cd "${0:A:h}/.."
DIR=".signature"
KC="$PWD/$DIR/dictee.keychain-db"
if [[ -f "$KC" ]]; then echo "Certificat déjà présent."; exit 0; fi
mkdir -p "$DIR" && chmod 700 "$DIR"
PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
echo -n "$PW" > "$DIR/mot-de-passe" && chmod 600 "$DIR/mot-de-passe"
cat > "$DIR/cert.cnf" <<C
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=Dictee local
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
C
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 7300 -config "$DIR/cert.cnf" \
  -keyout "$DIR/cle.pem" -out "$DIR/cert.pem" 2>/dev/null
/usr/bin/openssl pkcs12 -export -inkey "$DIR/cle.pem" -in "$DIR/cert.pem" -out "$DIR/cert.p12" -passout pass:"$PW"
security create-keychain -p "$PW" "$KC"
security set-keychain-settings "$KC"
security unlock-keychain -p "$PW" "$KC"
security import "$DIR/cert.p12" -k "$KC" -P "$PW" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PW" "$KC" >/dev/null
rm -f "$DIR/cle.pem" "$DIR/cert.p12"
echo "Certificat créé : Dictee local"
