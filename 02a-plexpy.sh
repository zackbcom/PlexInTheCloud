#!/bin/bash
source vars

## INFO
# This script installs plexpy
##

#######################
# Pre-Install
#######################
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Execute 'sudo su' to swap to the root user." 
   exit 1
fi

#######################
# Install
#######################
git clone https://github.com/JonnyWong16/plexpy.git /opt/plexpy/

#######################
# Systemd Service File
#######################
tee "/etc/systemd/system/plexpy.service" > /dev/null <<EOF
[Unit]
Description=PlexPy - Stats for Plex Media Server usage
After=plexmediaserver.service

[Service]
ExecStart=/opt/plexpy/PlexPy.py --quiet --daemon --nolaunch --config /opt/plexpy/config.ini --datadir /opt/plexpy
GuessMainPID=no
Type=forking
User=$username
Group=$username

[Install]
WantedBy=multi-user.target
EOF

#######################
# Permissions
#######################
chown -R $username:$username /opt/plexpy

#######################
# Autostart
#######################
systemctl daemon-reload
systemctl start plexpy
systemctl enable plexpy

#######################
# Remote Access
#######################
echo ''
echo "Do you want to allow remote access to PlexPy?"
echo "If so, you need to tell UFW to open the port."
echo "Otherwise, you can use SSH port forwarding."
echo ''
echo "Would you like us to open the port in UFW?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) ufw allow 8181; echo ''; echo "Port 8181 open, PlexPy is now available over the internet."; echo ''; break;;
        No ) echo "Port 8181 left closed. You can still access it on your local machine by issuing the following command: ssh $username@$ipaddr -L 8181:localhost:8181"; echo "and then open localhost:8181 on your browser."; exit;;
    esac
done
