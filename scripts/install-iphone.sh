#!/bin/zsh
# Dərmanchı-nı qoşulmuş iPhone-a yığır və quraşdırır.
# Pulsuz Apple ID ilə tətbiq 7 gün işləyir — sonra bu skripti yenidən işə sal.
set -e
cd "$(dirname "$0")/.."
DERIVED=~/Library/Developer/Xcode/DerivedData/Dermanchi-cli

JSON=$(mktemp)
xcrun devicectl list devices --quiet --json-output "$JSON" >/dev/null 2>&1
DEVICE=$(python3 -c '
import json, sys
for d in json.load(open(sys.argv[1]))["result"]["devices"]:
    if d["hardwareProperties"]["deviceType"] == "iPhone" and d["connectionProperties"].get("tunnelState") != "unavailable":
        print(d["identifier"]); break
' "$JSON")
rm -f "$JSON"
if [[ -z "$DEVICE" ]]; then
  echo "❌ iPhone tapılmadı. Kabellə qoş, kilidi aç və 'Bu kompüterə güvən' de."
  exit 1
fi

echo "📦 Yığılır..."
xcodebuild build -project Dermanchi.xcodeproj -scheme Dermanchi \
  -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates -quiet

echo "📲 Quraşdırılır ($DEVICE)..."
xcrun devicectl device install app --device "$DEVICE" "$DERIVED/Build/Products/Debug-iphoneos/Dermanchi.app"
echo "✅ Hazırdır. İlk dəfə: Ayarlar → Ümumi → VPN və Cihaz İdarəetməsi → sertifikata güvən."
