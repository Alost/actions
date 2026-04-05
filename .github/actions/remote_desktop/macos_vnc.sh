#!/usr/bin/env bash
set -euxo pipefail
export MSYS2_ARG_CONV_EXCL="*"

# https://github.com/dikeckaan/MacOS-Workflow-VNC 主参考
# https://github.com/UnQOfficial/remote-desktop-workflows 这个密码设不进去

VNC_USER=vncuser
VNC_PASSWORD=${1:-P@ssw0rd123!}

# disable spotlight indexing
sudo mdutil -i off -a

# Create new account
sudo dscl . -create /Users/$VNC_USER
sudo dscl . -create /Users/$VNC_USER UserShell /bin/bash
sudo dscl . -create /Users/$VNC_USER RealName $VNC_USER
sudo dscl . -create /Users/$VNC_USER UniqueID 1001
sudo dscl . -create /Users/$VNC_USER PrimaryGroupID 80
sudo dscl . -create /Users/$VNC_USER NFSHomeDirectory /Users/$VNC_USER
sudo dscl . -passwd /Users/$VNC_USER $VNC_PASSWORD
sudo dscl . -passwd /Users/$VNC_USER $VNC_PASSWORD
sudo createhomedir -c -u $VNC_USER > /dev/null
sudo dscl . -append /Groups/admin GroupMembership $VNC_USER

# Enable VNC
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -allowAccessFor -allUsers -privs -all
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes

# VNC password - http://hints.macworld.com/article.php?story=20071103011608872
echo $VNC_PASSWORD | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

# Start VNC/reset changes
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

# ngrok
# https://dashboard.ngrok.com/get-started/your-authtoken
if [ -n "${NGROK_AUTH_TOKEN:-}" ]; then
    brew install ngrok
    ngrok authtoken $NGROK_AUTH_TOKEN
    ngrok tcp 5900 --region=ap &
    # curl --silent http://127.0.0.1:4040/api/tunnels | jq '.tunnels[0].public_url'
fi

# cloudflared
# brew install cloudflare/cloudflare/cloudflared
# cloudflared tunnel --url tcp://localhost:5900 > tunnel.log 2>&1 &
# sleep 15
# cat tunnel.log | grep -o 'https://[^[:space:]]*trycloudflare.com' || echo "Check logs for tunnel URL"

# cloudflared access tcp --hostname https://list-manitoba-curtis-perl.trycloudflare.com --url localhost:5900
# localhost:5900
# vncuser P@ssw0rd123!
# 网络不好
