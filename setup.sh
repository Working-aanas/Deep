#!/usr/bin/env bash
###############################################################################
#  Google Colab - Chrome Remote Desktop + LXQt ultralight desktop
#  Works on the free Tesla T4 runtime (April 2025)
###############################################################################
set -euo pipefail
IFS=$'\n\t'

##### ─── EDIT THESE IF YOU LIKE ──────────────────────────────────────────────
CRD_PIN="123456"            # 6-digit PIN Google asks for on first connect
NEW_USER="colab"            # desktop username (≠ root)
NEW_PASS="colab"            # initial password   (change later!)
###############################################################################

[[ $EUID -eq 0 ]] || { echo "❌ Run as root (prepend: sudo)"; exit 1; }

echo "👉 1/6  Base prerequisites"
apt-get update -qq
apt-get install -y --no-install-recommends \
        gnupg curl ca-certificates software-properties-common dbus-x11 x11-utils

echo "👉 2/6  Google signing key + apt repos"
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | \
        gpg --dearmor -o /usr/share/keyrings/google.gpg
tee /etc/apt/sources.list.d/google.list >/dev/null <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/google.gpg] http://dl.google.com/linux/chrome/deb/ stable main
deb [arch=amd64 signed-by=/usr/share/keyrings/google.gpg] https://dl.google.com/linux/chrome-remote-desktop/deb/ stable main
EOF

echo "👉 3/6  Install Chrome, CRD and a minimal LXQt desktop"
apt-get update -qq
apt-get install -y --no-install-recommends \
        google-chrome-stable chrome-remote-desktop \
        lxqt-core lxqt-config xserver-xorg-video-dummy openbox \
        pcmanfm lxqt-panel lxqt-sudo nano

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

# Fixed virtual screen size keeps bandwidth predictable
echo "CHROME_REMOTE_DESKTOP_DEFAULT_DESKTOP_SIZES=1920x1080" >>/etc/environment

###############################################################################
echo "👉 6/6  Register the CRD host and keep it alive (no systemd in Colab)"
###############################################################################
echo "   ▸ In your browser, open:  https://remotedesktop.google.com/headless"
echo "   ▸ Choose **Debian Linux** and copy the long command beginning with 'DISPLAY='"
read -rp $'Paste that whole line here:\n> ' CRD_REGISTER

# Register the host once, as the desktop user
su - "$NEW_USER" -c "${CRD_REGISTER} --pin=${CRD_PIN}"

# Start the CRD daemon in the foreground (as desktop user), background the shell
su - "$NEW_USER" -c '/opt/google/chrome-remote-desktop/chrome-remote-desktop --start --foreground' &
CRD_PID=$!

# ── Heartbeat every 5 min to keep the Colab VM alive ────────────────────────
while kill -0 "$CRD_PID" 2>/dev/null; do
    echo "[CRD-LXQt] $(date --iso-8601=seconds) – host is up"
    sleep 300
done
echo "❌  CRD process exited – check the log above."
