#!/usr/bin/env bash
set -euxo pipefail
export MSYS2_ARG_CONV_EXCL="*"

PASSWORD=${1:-P@ssw0rd123!}

brew install cloudflare/cloudflare/cloudflared

sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -restart -agent -privs -all -allowAccessFor -allUsers
sudo defaults write /var/db/launchd.db/com.apple.launchd/overrides.plist com.apple.screensharing -dict Disabled -bool false

sudo mkdir -p /Library/Preferences
echo "$PASSWORD" | sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
    -activate -configure -access -on -restart -agent -privs -all \
    -clientopts -setvnclegacy -vnclegacy yes -setvncpw -vncpw "$PASSWORD"

sudo /usr/libexec/PlistBuddy -c "Add :VNCLegacyPasswords array" /Library/Preferences/com.apple.RemoteManagement.plist 2>/dev/null || true
sudo /usr/libexec/PlistBuddy -c "Delete :VNCLegacyPasswords:0" /Library/Preferences/com.apple.RemoteManagement.plist 2>/dev/null || true
HASH=$(python3 - <<PY
import sys,hashlib
print(hashlib.md5(b"$PASSWORD").hexdigest())
PY
)
sudo /usr/libexec/PlistBuddy -c "Add :VNCLegacyPasswords:0 data $(echo $HASH | xxd -r -p | base64)" /Library/Preferences/com.apple.RemoteManagement.plist
sudo launchctl unload /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist

cloudflared tunnel --url tcp://localhost:5900 > tunnel.log 2>&1 &
sleep 15
cat tunnel.log | grep -o 'https://[^[:space:]]*trycloudflare.com' || echo "Check logs for tunnel URL"

# cloudflared access tcp --hostname https://roulette-dean-choices-demands.trycloudflare.com --url localhost:5900
# vnc://localhost:5900
# vncuser P@ssw0rd123!
