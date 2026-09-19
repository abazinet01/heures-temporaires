#!/bin/zsh
# -----------------------------------------------------------------------------
# Construit « Heures temporaires.app » dans build/.
#
#   ./macos/construire.sh              construire seulement
#   ./macos/construire.sh --installer  construire, copier dans ~/Applications, lancer
#
# Pas besoin d'Xcode : les outils de ligne de commande suffisent (et évitent
# d'avoir à accepter la licence d'Xcode).
# -----------------------------------------------------------------------------
set -euo pipefail
export DEVELOPER_DIR=/Library/Developer/CommandLineTools

ICI=${0:A:h}
RACINE=${ICI:h}
NOM="Heures temporaires"
APP="$RACINE/build/$NOM.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/web"

swiftc -O -swift-version 5 -target arm64-apple-macos13 \
  -o "$APP/Contents/MacOS/HeuresTemporaires" "$ICI"/Sources/*.swift

cp "$ICI/Info.plist" "$APP/Contents/Info.plist"

# La page, telle quelle : la même que sur GitHub Pages.
cp "$RACINE/index.html" "$RACINE/soleil.js" "$APP/Contents/Resources/web/"

[[ -f "$ICI/Icone.icns" ]] || swift "$ICI/outils/icone.swift" "$ICI/Icone.icns"
cp "$ICI/Icone.icns" "$APP/Contents/Resources/"

# Signature « ad hoc » : suffisante pour un usage personnel sur ce Mac.
codesign --force --sign - "$APP"
echo "Construit : $APP"

if [[ "${1:-}" == "--installer" ]]; then
  pkill -x HeuresTemporaires 2>/dev/null && sleep 0.5 || true
  mkdir -p ~/Applications
  rm -rf ~/Applications/"$NOM.app"
  ditto "$APP" ~/Applications/"$NOM.app"
  open ~/Applications/"$NOM.app"
  echo "Installé et lancé : ~/Applications/$NOM.app"
fi
