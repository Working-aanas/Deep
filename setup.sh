#!/bin/bash

# Set DNF to assume yes
export DNF_YUM_AUTO_YES=1

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Function to create user
create_user() {
    echo "Please visit http://remotedesktop.google.com/headless and copy the command after Authentication"
    read -p "Paste the CRD SSH command here: " CRD
    echo "Creating User and Setting it up"
    username="disala"
    password="root"
    Pin="123456"

    useradd -m "$username"
    echo "$username:$password" | passwd --stdin "$username"
    usermod -aG wheel "$username"

    echo 'export PATH=$PATH:/home/user/.local/bin' >> /home/"$username"/.bashrc
    su - "$username" -c "source ~/.bashrc"

    echo "User '$username' created and configured."
}

# Extra storage setup
setup_storage() {
    mkdir -p /storage
    chmod 777 /storage
    chown "$username":"$username" /storage
    mkdir -p /home/"$username"/storage
    mount --bind /storage /home/"$username"/storage
}

# Function to install and configure RDP
setup_rdp() {
    echo "Installing Google Chrome"
    dnf install -y fedora-workstation-repositories
    dnf config-manager --set-enabled google-chrome
    dnf install -y google-chrome-stable

    echo "Installing Firefox ESR (if not already)"
    dnf install -y firefox

    echo "Installing dependencies"
    dnf install -y dbus-x11 dbus python3-packaging python3-psutil python3-xdg xorg-x11-server-Xvfb xorg-x11-drv-dummy xorg-x11-xauth nload qbittorrent ffmpeg gpac fuse-libs tmate

    echo "Installing Chrome Remote Desktop"
    wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_x86_64.rpm
    dnf install -y ./chrome-remote-desktop_current_x86_64.rpm

    echo "Setting up Desktop Environment for CRD"
    echo "exec /usr/bin/gnome-session" > /etc/chrome-remote-desktop-session

    systemctl disable gdm.service

    echo "Adding user to chrome-remote-desktop group"
    usermod -aG chrome-remote-desktop "$username"

    echo "Wallpaper and customization (Optional)"
    # You can set a wallpaper here if needed. Nobara uses GNOME/KDE, not XFCE.
    # Example for GNOME:
    # sudo -u "$username" gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/YourBackground.jpg'

    su - "$username" -c "$CRD --pin=$Pin"
    systemctl enable chrome-remote-desktop@$username

    echo "RDP setup completed"
}

# Execute functions
create_user
setup_rdp

# Keep-alive loop
echo "Starting keep-alive loop. Press Ctrl+C to stop."
while true; do
    echo "I'm alive"
    sleep 300
done
