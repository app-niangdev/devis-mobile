#!/usr/bin/env bash
# Construit l'application Android de production, branchée sur l'API du VPS.
# Usage : ./deploy/build_android.sh [adresse-api]
#   -> build/app/outputs/flutter-apk/app-release.apk   (installation directe / partage WhatsApp)
#   -> build/app/outputs/bundle/release/app-release.aab (Google Play)
#
# Clé de signature (une seule fois, à sauvegarder hors du projet : sans elle, plus de mise à jour possible) :
#   keytool -genkey -v -keystore ~/devis-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
# puis android/key.properties :
#   storeFile=/Users/<vous>/devis-upload.jks
#   storePassword=...
#   keyAlias=upload
#   keyPassword=...
set -euo pipefail

API_URL="${1:-https://backenddevis.niangdev.com/api}"
case "$API_URL" in
  https://*) ;;
  *) echo "L'API doit être en HTTPS (Android bloque le HTTP en clair en production)." >&2; exit 1 ;;
esac

cd "$(dirname "$0")/.."
[ -f android/key.properties ] || echo "⚠ android/key.properties absent : APK signé avec la clé de debug (refusé par Google Play)." >&2

flutter pub get
flutter build apk --release --dart-define=API_URL="$API_URL"
flutter build appbundle --release --dart-define=API_URL="$API_URL"
echo "APK : build/app/outputs/flutter-apk/app-release.apk"
echo "AAB : build/app/outputs/bundle/release/app-release.aab"
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')
echo
echo "Publier la version $VERSION :"
echo "  1. scp build/app/outputs/flutter-apk/app-release.apk <vps>:/var/www/devis-pwa/devis.apk"
echo "  2. Sur le VPS, /opt/devis/backend/.env : MOBILE_LATEST_VERSION=$VERSION"
echo "     (et MOBILE_MIN_VERSION=$VERSION pour imposer la mise à jour)"
echo "  3. cd /opt/devis && docker compose up -d backend"
