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

# Setup storage
setup_storage() {
    mkdir -p /storage
    chmod 777 /storage
    chown "$username":"$username" /storage
    mkdir -p /home/"$username"/storage
    mount --bind /storage /home/"$username"/storage
}

# Install Windows 10 VM
setup_windows_vm() {
    echo "Installing virtualization packages"
    apt update
    apt install --assume-yes qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager

    echo "Creating Windows 10 virtual machine"
    mkdir -p /var/lib/libvirt/images/windows10
    cd /var/lib/libvirt/images/windows10

    echo "Downloading Windows 10 ISO (Evaluation version)"
    wget -O win10.iso "https://software-download.microsoft.com/db/Win10_22H2_English_x64.iso"

    echo "Creating virtual hard disk"
    qemu-img create -f qcow2 win10.img 60G

    echo "Starting Windows 10 installation in background"

    virt-install \
        --name windows10 \
        --memory 4096 \
        --vcpus 2 \
        --disk path=/var/lib/libvirt/images/windows10/win10.img,format=qcow2 \
        --cdrom /var/lib/libvirt/images/windows10/win10.iso \
        --os-type windows \
        --os-variant win10 \
        --network network=default \
        --graphics vnc,listen=0.0.0.0 \
        --noautoconsole \
        --boot cdrom,hd

    echo "Windows 10 VM is now installing. Connect via VNC Viewer to the server IP."
}

# Install Chrome Remote Desktop
setup_crd() {
    echo "Installing Chrome Remote Desktop"
    wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
    dpkg --install chrome-remote-desktop_current_amd64.deb
    apt install --assume-yes --fix-broken

    echo "Finalizing CRD setup"
    adduser "$username" chrome-remote-desktop

    su - "$username" -c "$CRD --pin=$Pin"
    service chrome-remote-desktop start
}

# Execute functions
create_user
setup_windows_vm
setup_crd
setup_storage

# Keep-alive loop
echo "Starting keep-alive loop. Press Ctrl+C to stop."
while true; do
    echo "I'm alive"
    sleep 300
done
