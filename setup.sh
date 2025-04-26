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
     password="MyStrongPassword123"  # Password must be at least 8 characters
     password="root"
     Pin="123456"
     
 
     useradd -m "$username"
     adduser "$username" sudo
     echo "$username:$password" | sudo chpasswd
     sed -i 's/\/bin\/sh/\/bin\/bash/g' /etc/passwd
 
     # Add PATH update to .bashrc of the new user
     echo 'export PATH=$PATH:/home/user/.local/bin' >> /home/"$username"/.bashrc
     # Fix PATH
     echo 'export PATH=$PATH:$HOME/.local/bin' >> /home/"$username"/.bashrc
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
     wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
     dpkg --install google-chrome-stable_current_amd64.deb
     apt install --assume-yes --fix-broken
     dpkg --install google-chrome-stable_current_amd64.deb || apt install --assume-yes --fix-broken
 
     echo "Installing Firefox ESR"
     add-apt-repository ppa:mozillateam/ppa -y  
     apt update
     apt install --assume-yes firefox-esr
     apt install --assume-yes dbus-x11 dbus 
     apt install --assume-yes firefox-esr dbus-x11 dbus 
 
     echo "Installing dependencies"
     apt update
     add-apt-repository universe -y
     apt install --assume-yes xvfb xserver-xorg-video-dummy xbase-clients python3-packaging python3-psutil python3-xdg libgbm1 libutempter0 libfuse2 nload qbittorrent ffmpeg gpac fonts-lklug-sinhala
     apt install --assume-yes tmate
 
     echo "Installing KDE Plasma Desktop Environment"
     apt install --assume-yes kde-plasma-desktop sddm
     echo "exec startplasma-x11" > /etc/chrome-remote-desktop-session
     apt install --assume-yes xscreensaver
     systemctl disable sddm.service || true
 
     echo "Optimizing KDE Plasma for Speed (Disabling Animations and Effects)"
     mkdir -p /home/"$username"/.config
 
     # Disable compositing and effects
     su - "$username" -c 'kwriteconfig5 --file kwinrc --group Compositing --key Enabled false'
     su - "$username" -c 'kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_blurEnabled false'
     su - "$username" -c 'kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_fadeEnabled false'
     su - "$username" -c 'kwriteconfig5 --file kwinrc --group Plugins --key kwin4_effect_zoomEnabled false'
     su - "$username" -c 'kwriteconfig5 --file kdeglobals --group KDE --key GraphicEffectsLevel 0'
     su - "$username" -c 'kwriteconfig5 --file kdeglobals --group KDE --key AnimationsEnabled false'
     su - "$username" -c 'kwriteconfig5 --file kdeglobals --group General --key forceFontDPI 96'
 
     # Set a lightweight plasma theme (Optional)
     su - "$username" -c 'kwriteconfig5 --file plasmarc --group Theme --key name BreezeLight'
     apt install --assume-yes \
       xvfb xserver-xorg-video-dummy xbase-clients \
       python3-packaging python3-psutil python3-xdg \
       libgbm1 libutempter0 libfuse2 \
       nload qbittorrent ffmpeg gpac \
       fonts-lklug-sinhala tmate mesa-utils libgl1-mesa-dri libgl1-mesa-glx \
       cpufrequtils pulseaudio lxqt xscreensaver
 
     echo "Installing Chrome Remote Desktop"
     wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb
     dpkg --install chrome-remote-desktop_current_amd64.deb
     apt install --assume-yes --fix-broken
     dpkg --install chrome-remote-desktop_current_amd64.deb || apt install --assume-yes --fix-broken
 
     echo "Setting LXQt as Desktop Session"
     echo "exec startlxqt" > /etc/chrome-remote-desktop-session
 
     # CPU governor to Performance mode
     cpufreq-set -g performance
 
     # PulseAudio setup
     systemctl --user start pulseaudio || pulseaudio --start
 
     echo "Optimizing X11 settings for Dummy display"
     cat > /etc/X11/xorg.conf <<EOF
 Section "Device"
   Identifier "Configured Video Device"
   Driver "dummy"
 EndSection
 
 Section "Monitor"
   Identifier "Configured Monitor"
   HorizSync 31.5-48.5
   VertRefresh 50-70
 EndSection
 
 Section "Screen"
   Identifier "Default Screen"
   Monitor "Configured Monitor"
   Device "Configured Video Device"
   DefaultDepth 24
   SubSection "Display"
     Depth 24
     Modes "1920x1080"
   EndSubSection
 EndSection
 EOF
 
     echo "Tuning Chrome Remote Desktop for low latency"
     echo "ENABLE_TUNING=true" >> /etc/chrome-remote-desktop-session.conf
 
     echo "Disabling unnecessary services"
     systemctl disable lightdm.service
     systemctl disable bluetooth.service
     systemctl disable avahi-daemon.service
     systemctl disable cups.service
 
     echo "Finalizing setup"
     adduser "$username" chrome-remote-desktop
     curl -s -L -k -o xfce-shapes.svg https://raw.githubusercontent.com/The-Disa1a/Cloud-Shell-GCRD/refs/heads/main/Wall/xfce-shapes.svg
     mv xfce-shapes.svg /usr/share/backgrounds/xfce/
 
     echo "Wallpaper Changed"
 
     su - "$username" -c "$CRD --pin=$Pin"
     service chrome-remote-desktop start
 
     setup_storage "$username"
 
     echo "RDP setup completed"
     echo "RDP setup completed!"
 }
 
 # Execute functions
 create_user
 setup_rdp
 
 # Keep-alive loop
 echo "Starting keep-alive loop. Press Ctrl+C to stop."
 while true; do
     echo "I'm alive"
     sleep 300  # Sleep for 5 minutes
     sleep 300
 done
