#!/usr/bin/env bash
###############################################################################
#  ultra-light Chrome Remote Desktop for Google Colab (Tesla T4, April 2025)
#  - zero interactive prompts
#  - ≥ Debian 11 / Ubuntu 20.04 container
###############################################################################
set -euo pipefail
IFS=$'\n\t'

#### ─── EDITABLE VARIABLES ────────────────────────────────────────────────
CRD_PIN="123456"            # 6-digit PIN Google asks for on first connect
NEW_USER="colab"            # your desktop username  (≠ root)
NEW_PASS="colab"            # initial password      (change later!)
############################################################################

[[ $EUID -eq 0 ]] || { echo "❌ Run as root (prepend: sudo)"; exit 1; }

echo "👉 1/6  System prerequisites"
apt-get update -qq
apt-get install -y --no-install-recommends \
        gnupg curl ca-certificates software-properties-common dbus-x11 x11-utils

echo "👉 2/6  Google signing key + repos"
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub |
        gpg --dearmor -o /usr/share/keyrings/google.gpg
tee /etc/apt/sources.list.d/google.list >/dev/null <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/google.gpg] http://dl.google.com/linux/chrome/deb/ stable main
deb [arch=amd64 signed-by=/usr/share/keyrings/google.gpg] https://dl.google.com/linux/chrome-remote-desktop/deb/ stable main
EOF

echo "👉 3/6  Install Chrome + CRD + LXQt (minimal)"
apt-get update -qq
apt-get install -y --no-install-recommends \
        google-chrome-stable chrome-remote-desktop \
        lxqt-core lxqt-config xserver-xorg-video-dummy openbox

# Optional: basic extras (remove if you want *absolute* minimum)
apt-get install -y --no-install-recommends pcmanfm lxqt-panel lxqt-sudo nano

echo "👉 4/6  Create non-root desktop user"
id -u "$NEW_USER" &>/dev/null || useradd -m -s /bin/bash "$NEW_USER"
echo "$NEW_USER:$NEW_PASS" | chpasswd
adduser "$NEW_USER" sudo
adduser "$NEW_USER" chrome-remote-desktop   # CRD must run under this group

echo "👉 5/6  Wire LXQt into CRD"
cat >/etc/chrome-remote-desktop-session <<'EOF'
#!/bin/sh
exec /usr/bin/startlxqt
EOF
chmod +x /etc/chrome-remote-desktop-session

# A fixed virtual screen avoids CRD resolution switches → less bandwidth
echo "CHROME_REMOTE_DESKTOP_DEFAULT_DESKTOP_SIZES=1920x1080" >>/etc/environment

###############################################################################
# 6/6  Register the host and start it manually (no systemd inside Colab!)
###############################################################################
echo "👉 6/6  Ask Google for the one-time auth string"
echo "   ▸ In your browser:  https://remotedesktop.google.com/headless"
echo "   ▸ Choose **Debian Linux** and copy the command that begins with 'DISPLAY='"
read -rp $'Paste that whole line here:\n> ' CRD_REGISTER

# Register + launch the host exactly once, under the desktop user
su - "$NEW_USER" -c "${CRD_REGISTER} --pin=${CRD_PIN}"

# ── Keep the CRD daemon (and the notebook) alive ────────────────────────────
/opt/google/chrome-remote-desktop/chrome-remote-desktop --start \
        --user="$NEW_USER" \
        --foreground &           # <-- runs in the background, but ties to this shell

# “I’m alive” heartbeat so Colab sees activity every 5 min
while true; do
    echo "[CRD-LXQt] $(date --iso-8601=seconds) – up and healthy"
    sleep 300
done
