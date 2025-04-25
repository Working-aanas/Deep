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
    echo "Creating user and setting it up..."
    
    username="disala"
    password="root"
    Pin="123456"

    useradd -m "$username"
    echo "$username:$password" | passwd --stdin "$username"
    usermod -aG wheel "$username"

    # Fix .bashrc PATH
    echo 'export PATH=$PATH:/home/'"$username"'/.local/bin' >> /home/"$username"/.bashrc
    chown "$username":"$username" /home/"$username"/.bashrc

    echo "User '$username' created and configured."

    # Store CRD and Pin for later
    echo "$CRD" > /home/"$username"/crd-command.sh
    echo "$Pin" > /home/"$username"/crd-pin.txt
    chmod +x /home/"$username"/crd-command.sh
    chown "$username":"$username" /home/"$username"/crd-command.sh /home/"$username"/crd-pin.txt
}

# Function for setting up storage mount
setup_storage() {
    echo "Setting up extra storage..."
    mkdir -p /storage
    chmod 777 /storage
    chown "$username":"$username" /storage

    mkdir -p /home/"$username"/storage
    mount --bind /storage /home/"$username"/storage
    echo "/storage /home/$username/storage none bind 0 0" >> /etc/fstab
}

# Function to install packages and CRD
setup_rdp() {
    echo "Installing Google Chrome and other dependencies..."

    # Chrome installation
    dnf install -y fedora-workstation-repositories
    dnf config-manager --set-enabled google-chrome
    dnf install -y google-chrome-stable

    # Firefox (already present in Nobara, but just in case)
    dnf install -y firefox

    # Other dependencies
    dnf install -y dbus-x11 dbus python3-packaging python3-psutil python3-xdg \
        xorg-x11-server-Xvfb xorg-x11-drv-dummy xorg-x11-xauth \
        nload qbittorrent ffmpeg gpac fuse-libs tmate

    echo "Installing Chrome Remote Desktop..."
    wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_x86_64.rpm
    dnf install -y ./chrome-remote-desktop_current_x86_64.rpm

    echo "Configuring Desktop Environment for CRD..."
    echo "exec /usr/bin/gnome-session" > /etc/chrome-remote-desktop-session

    echo "Adding user to CRD group..."
    usermod -aG chrome-remote-desktop "$username"

    echo "Authenticating Chrome Remote Desktop for the user..."
    su - "$username" -c "/home/$username/crd-command.sh --pin=$(cat /home/$username/crd-pin.txt)"

    echo "Chrome Remote Desktop setup completed!"
}

# Execute the functions
create_user
setup_rdp
setup_storage

# Keep-alive loop
echo "Starting keep-alive loop. Press Ctrl+C to stop."
while true; do
    echo "I'm alive"
    sleep 300
done
