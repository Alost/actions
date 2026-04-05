#!/usr/bin/env bash
set -euxo pipefail
export MSYS2_ARG_CONV_EXCL="*"

# https://github.com/iambjlu/MacOS-Workflow-VNC
# https://github.com/dikeckaan/MacOS-Workflow-VNC 黑屏
# https://github.com/UnQOfficial/remote-desktop-workflows 密码不对，要小写?

VNC_USER=vncuser
VNC_PASSWORD=${1:-P@ssw0rd123!}

# disable spotlight indexing
sudo defaults write ~/.Spotlight-V100/VolumeConfiguration.plist Exclusions -array "/Volumes" || true
sudo defaults write ~/.Spotlight-V100/VolumeConfiguration.plist Exclusions -array "/Network" || true
sudo killall mds || true
sleep 3
sudo mdutil -a -i off / || true
sudo mdutil -a -i off || true
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist || true
sudo rm -rf /.Spotlight-V100/*
sudo rm -rf ~/Library/Metadata/CoreSpotlight/ || true
killall -KILL Spotlight spotlightd mds || true
sudo rm -rf /System/Volums/Data/.Spotlight-V100 || true

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

csrutil status
sudo python3 -c "
import sqlite3
import time
import os

db_path = '/Library/Application Support/com.apple.TCC/TCC.db'
if not os.path.exists(db_path):
    print(f'❌ Error: DB not found at {db_path}')
    exit(1)

try:
    con = sqlite3.connect(db_path)
    cur = con.cursor()

    # 定義我們要授權的服務
    # 1. kTCCServiceScreenCapture: 允許看畫面
    # 2. kTCCServicePostEvent: 允許控制滑鼠鍵盤
    # 3. kTCCServiceAccessibility: 輔助使用權限 (有時候需要)
    services = [
        'kTCCServiceScreenCapture',
        'kTCCServicePostEvent',
        'kTCCServiceAccessibility'
    ]

    # 目標程式：macOS 內建螢幕分享代理程式
    client = 'com.apple.screensharing.agent'

    # 獲取當前時間戳
    now = int(time.time())

    # 針對每個服務進行注入
    for service in services:
        print(f'💉 Injecting {service} for {client}...')

        # 這是 macOS 12+ (含 Sequoia) 常見的 TCC 表結構插入
        # 使用 INSERT OR REPLACE 覆蓋舊設定
        # auth_value=2 代表 'Allowed'
        cur.execute('''
            INSERT OR REPLACE INTO access
            (service, client, client_type, auth_value, auth_reason, auth_version, csreq, policy_id, indirect_object_identifier_type, indirect_object_identifier, flags, last_modified)
            VALUES (?, ?, 0, 2, 4, 1, NULL, NULL, 0, 'UNUSED', 0, ?)
        ''', (service, client, now))

    con.commit()
    print('TCC Permissions injected successfully.')
    con.close()

except Exception as e:
    print(f'❌ TCC Injection Failed: {e}')
    # 如果是因為欄位數量不對 (macOS 版本差異)，這裡會報錯，但通常 macOS 15 結構如上
    exit(1)
"
sudo defaults write /Library/Preferences/com.apple.universalaccess reduceTransparency -bool true
sudo defaults write /Library/Preferences/com.apple.universalaccess reduceMotion -bool true
sudo defaults write /Library/Preferences/com.apple.dock launchanim -bool false
sudo defaults write com.apple.dock mineffect -string scale
killall Dock
sudo defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
sudo defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
sudo defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
killall Finder
sudo ln -s / ~/Desktop/Macintosh\ HD
sudo ln -s ~ ~/Desktop
sudo ln -s / /Users/vncuser/Desktop/Macintosh\ HD
sudo ln -s /Users/ /Users/vncuser/Desktop
open -a Terminal && sleep 1 && osascript -e 'tell application "Terminal" to quit'
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
open /System/Library/PreferencePanes/Displays.prefPane

sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate -configure -access -off
sleep 1

sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on \
  -clientopts -setvnclegacy -vnclegacy yes \
  -clientopts -setvncpw -vncpw "$VNC_PASSWORD" \
  -restart -agent -privs -all -allowAccessFor -allUsers

sudo dseditgroup -o edit -a "$(whoami)" -t user com.apple.access_screensharing

# VNC password - http://hints.macworld.com/article.php?story=20071103011608872
echo $VNC_PASSWORD | perl -we 'BEGIN { @k = unpack "C*", pack "H*", "1734516E8BA8C5E2FF1C39567390ADCA"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack "C*", $_; foreach (@k) { printf "%02X", $_ ^ (shift @p || 0) }; print "\n"' | sudo tee /Library/Preferences/com.apple.VNCSettings.txt

# Start VNC/reset changes
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -restart -agent -console
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate

name="Mac-$( [ "$(uname -m)" = "arm64" ] && echo M1 || echo Intel )-macOS-$(sw_vers -productVersion | cut -d. -f1)"
sudo scutil --set HostName $name
sudo scutil --set LocalHostName $name
sudo scutil --set ComputerName $name
sudo dscacheutil -flushcache

# ngrok
# https://dashboard.ngrok.com/get-started/your-authtoken
# if [ -n "${NGROK_AUTHTOKEN:-}" ]; then
#     brew install ngrok
#     ngrok authtoken $NGROK_AUTHTOKEN
#     ngrok tcp 5900 &
#     sleep 3
#     url=$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')
#     if [ -n "$url" ]; then
#         echo -e "\033[31m$url\033[0m"
#     fi
# fi

# cloudflared
# brew install cloudflare/cloudflare/cloudflared
# cloudflared tunnel --url tcp://localhost:5900 > tunnel.log 2>&1 &
# sleep 15
# cat tunnel.log | grep -o 'https://[^[:space:]]*trycloudflare.com' || echo "Check logs for tunnel URL"

# cloudflared access tcp --hostname https://list-manitoba-curtis-perl.trycloudflare.com --url localhost:5900
# localhost:5900
# vncuser P@ssw0rd123!

# ssh
# nano /etc/ssh/sshd_config.d/my.conf
# GatewayPorts yes
# AllowTcpForwarding yes
# systemctl reload sshd
echo "$SSH_KEY" > ~/.ssh/key
chmod 600 ~/.ssh/key
# ssh -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
#     -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
#     -o IdentitiesOnly=yes -i ~/.ssh/key \
#     -R :15900:localhost:5900 \
#     -N -f \
#     root@$SSH_IP -p $SSH_PORT
brew install autossh
export AUTOSSH_GATETIME=0
autossh -M 12345 \
    -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
    -o IdentitiesOnly=yes -i ~/.ssh/key \
    -R :15900:localhost:5900 \
    -N \
    root@$SSH_IP -p $SSH_PORT &
# lsof -i:15900
