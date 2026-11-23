#!/bin/zsh
# Tests unitaires du nettoyage du texte.
set -e
cd "${0:A:h}/.."
mkdir -p build
cat > build/main.swift <<'M'
import Foundation
MainActor.assumeIsolated { lancerTests() }
M
swiftc -O -o build/tests Sources/Dictee/Cleaner.swift Sources/Dictee/Store.swift Tests/test-nettoyage.swift build/main.swift
./build/tests
