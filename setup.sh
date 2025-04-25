#!/bin/bash

# Set DEBIAN_FRONTEND to noninteractive to suppress prompts
export DEBIAN_FRONTEND=noninteractive

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Function to create user
create_user() {
    echo "Please visit http://remotedesktop.google.com/headless and copy the command after Authentication"
    read -p "Paste the CRD SSH command here: " CRD
    echo "Creating user and setting it up..."

    username="disala"
    password="root"
    Pin="123456"

    if id "$username" &>/dev/null; then
        echo "User $username already exists. Skipping user creation."
    else
        useradd -m "$username"
        echo "$username:$password" | chpasswd
        usermod -aG sudo "$username"
        echo 'export PATH=$PATH:/home/'"$username"'/.local/bin' >> /home/"$username"/.bashrc
        chown "$username":"$username" /home/"$username"/.bashrc
        echo "User '$username' created and configured."
    fi

    # Save CRD command for use later
    echo "$CRD" > /home/"$username"/crd-command.sh
    chmod +x /home/"$username"/crd-command.sh
    chown "$username":"$username" /home/"$username"/crd-command.sh
}

# Function to setup storage
setup_storage() {
    echo "Setting up extra storage..."
    mkdir -p /storage
    chmod 777 /storage
    chown "$username":"$username" /storage

    mkdir -p /home/"$username"/storage
    mount --bind /storage /home/"$username"/storage
    grep -qxF "/storage /home/$username/storage none bind 0 0" /etc/fstab || echo "/storage /home/$username/storage none bind 0 0" >> /etc/fstab
}

# Function to install CRD and dependencies
setup_rdp() {
    echo "Installing necessary packages..."

    apt update
    apt install -y wget curl sudo xfce4 xfce4-terminal dbus-x11 \
        xbase-clients xserver-xorg-video-dummy xvfb python3-packaging \
        python3-psutil python3-xdg libgbm1 libutempter0 libfuse2 \
        nload qbittorrent ffmpeg gpac fonts-lklug-sinhala tmate

    echo "Installing Google Chrome..."
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt install -y ./google-chrome-stable_current_amd64.deb || apt --fix-broken install -y

    echo "Installing Chrome Remote Desktop..."
    wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
    apt install -y ./chrome-remote-desktop_current_amd64.deb || apt --fix-broken install -y

    echo "Configuring CRD to use XFCE4..."
    echo "exec /usr/bin/xfce4-session" > /etc/chrome-remote-desktop-session

    echo "Adding user to chrome-remote-desktop group..."
    groupadd chrome-remote-desktop || true
    usermod -aG chrome-remote-desktop "$username"

    echo "Authenticating Chrome Remote Desktop..."
    su - "$username" -c "/home/$username/crd-command.sh --pin=$Pin"

    echo "CRD setup completed successfully!"
}

# Execute functions
create_user
setup_rdp
setup_storage

# Keep-alive loop
echo "Starting keep-alive loop. Press Ctrl+C to stop."
while true; do
    echo "I'm alive"
    sleep 300
done
