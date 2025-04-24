#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

create_user() {
    echo "Please visit http://remotedesktop.google.com/headless and copy the command after Authentication"
    read -p "Paste the CRD SSH command here: " CRD
    echo "Creating User and Setting it up"
    username="disala"
    password="root"
    Pin="123456"
    
    useradd -m "$username"
    adduser "$username" sudo
    echo "$username:$password" | sudo chpasswd
    sed -i 's/\/bin\/sh/\/bin\/bash/g' /etc/passwd

    echo 'export PATH=$PATH:/home/user/.local/bin' >> /home/"$username"/.bashrc
    su - "$username" -c "source ~/.bashrc"

    echo "User '$username' created and configured."
}

setup_storage() {
    mkdir -p /storage
    chmod 777 /storage
    chown "$username":"$username" /storage
    mkdir -p /home/"$username"/storage
    mount --bind /storage /home/"$username"/storage
}

setup_rdp() {
    echo "Installing browsers"
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    dpkg --install google-chrome-stable_current_amd64.deb
    apt install --assume-yes --fix-broken

    add-apt-repository ppa:mozillateam/ppa -y  
    apt update
    apt install --assume-yes firefox-esr
    apt install --assume-yes dbus-x11 dbus 

    echo "Installing core dependencies"
    apt update
    add-apt-repository universe -y
    apt install --assume-yes xvfb xserver-xorg-video-dummy xbase-clients python3-packaging python3-psutil python3-xdg libgbm1 libutempter0 libfuse2 nload qbittorrent ffmpeg gpac fonts-lklug-sinhala
    sudo apt update && sudo apt install -y tmate

    echo "Installing Openbox minimal desktop"
    apt install --assume-yes openbox tint2 lxterminal pcmanfm xscreensaver
    echo "exec openbox-session" > /etc/chrome-remote-desktop-session

    apt remove --assume-yes gnome-terminal
    systemctl disable lightdm.service

    echo "Installing Chrome Remote Desktop"
    wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
    dpkg --install chrome-remote-desktop_current_amd64.deb
    apt install --assume-yes --fix-broken

    echo "Finalizing RDP setup"
    adduser "$username" chrome-remote-desktop
    curl -s -L -k -o openbox-wall.svg https://raw.githubusercontent.com/The-Disa1a/Cloud-Shell-GCRD/refs/heads/main/Wall/xfce-shapes.svg
    mv openbox-wall.svg /usr/share/backgrounds/openbox/

    su - "$username" -c "$CRD --pin=$Pin"
    service chrome-remote-desktop start
    setup_storage "$username"

    echo "RDP setup completed"
}

create_user
setup_rdp

echo "Starting keep-alive loop. Press Ctrl+C to stop."
while true; do
    echo "I'm alive"
    sleep 300
done
