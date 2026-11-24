#!/bin/bash
# Cài Flutter SDK (stable mới nhất) cho app HomeHub. Log: ~/workspace/homehub/flutter-install.log
set -e
cd ~/workspace/homehub
mkdir -p flutter-sdk
curl -s https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json -o releases_linux.json
URL=$(python3 - << 'PY'
import json, sys
d = json.load(open('releases_linux.json'))
rel = next(r for r in d['releases'] if r.get('channel') == 'stable')
# archive đã gồm 'stable/linux/...' nên chỉ cộng base_url
print(d['base_url'] + '/' + rel['archive'])
print('Phien ban: ' + rel['version'], file=sys.stderr)
PY
)
echo "Tai: $URL"
curl -L -o flutter.tar.xz "$URL"
ls -la flutter.tar.xz
tar -xf flutter.tar.xz -C flutter-sdk --strip-components=1
rm -f flutter.tar.xz
export PATH="$HOME/workspace/homehub/flutter-sdk/bin:$PATH"
flutter --version
flutter doctor || true
echo "XONG cai Flutter."
