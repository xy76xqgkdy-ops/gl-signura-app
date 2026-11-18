#!/usr/bin/env bash
# Baut die Flutter-Web-App und lädt sie auf gl.signura.de (signura-booin) hoch.
# Dateien auf dem Server, die nicht mehr im Build sind, werden gelöscht.
#
#   ./deploy.sh
set -euo pipefail

SERVER="${SIGNURA_SERVER:-root@167.233.242.200}"
REMOTE_DIR="/var/www/html"
URL="https://gl.signura.de"

cd "$(dirname "$0")"

echo "→ baue Web-App …"
flutter build web --release

echo "→ lade nach $SERVER:$REMOTE_DIR …"
rsync -a --delete --chmod=Da+rx,Fa+r build/web/ "$SERVER:$REMOTE_DIR/"

echo "→ prüfe $URL …"
status=$(curl -s -o /dev/null -w '%{http_code}' "$URL/")
api=$(curl -s "$URL/api/health" || true)
if [ "$status" != "200" ]; then
	echo "FEHLER: $URL antwortet mit HTTP $status" >&2
	exit 1
fi
echo "✓ Seite: HTTP $status"
echo "✓ API:   ${api:-keine Antwort}"
echo "Fertig. Im Browser ggf. mit Cmd+Shift+R neu laden."
