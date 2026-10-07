#!/usr/bin/env bash
# Construit la PWA (application web installable) dans build/web.
# Usage : ./deploy/build_pwa.sh https://backenddevis.niangdev.com/api
set -euo pipefail

API_URL="${1:?Adresse HTTPS de l’API requise, ex. https://backenddevis.niangdev.com/api}"
case "$API_URL" in
  https://*) ;;
  *) echo "L'API doit être en HTTPS : une PWA servie en HTTPS ne peut pas appeler une API en HTTP." >&2; exit 1 ;;
esac

cd "$(dirname "$0")/.."
flutter pub get
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')
flutter build web --release --dart-define=API_URL="$API_URL" --dart-define=APP_VERSION="$VERSION"
echo "PWA prête dans build/web — à copier sur le serveur (voir deploy/nginx-pwa.conf)."
