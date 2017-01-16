#!/bin/bash
source vars

## INFO
# This script installs and configures Plex.
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
if [ -n "$plexToken" ]; then
    wget "https://plex.tv/downloads/latest/1?channel=16&build=linux-ubuntu-x86_64&distro=ubuntu&X-Plex-Token=$plexToken"
else
    wget "https://plex.tv/downloads/latest/1?channel=16&build=linux-ubuntu-x86_64&distro=ubuntu"
fi

dpkg -i plex*.deb
rm plex*.deb

#######################
# Structure
#######################
mkdir -p /etc/systemd/system/plexmediaserver.service.d

#######################
# Systemd Service File
#######################
tee "/etc/systemd/system/plexmediaserver.service.d/local.conf" > /dev/null <<EOF
[Unit]
Description= Start Plexmediaserver as our user, and don't do it until our mount script has finished.
After=rcloneMount.service

[Service]
User=$username
Group=$username
EOF

#######################
# Permissions
#######################
chown -R $username:$username /var/lib/plexmediaserver

#######################
# Autostart
#######################
systemctl daemon-reload
systemctl start plexmediaserver
systemctl enable plexmediaserver 

#######################
# Remote Access
#######################
ufw allow 32400

#######################
# Misc.
#######################
cat << EOF
## ON LOCAL MACHINE - incognito works best for some reason
## otherwise Plex may tell you that it "can't save the settings"
## When you try to login via port forwarding.
# ssh $username@$ipaddr -L 8888:localhost:32400
#    open `localhost:8888/web` in a browser
#    login with your previously created Plex account.
#    if you don't have one, create one now.
#    Now enable remote access:
#        Remote Access-->Enable
#    Open IPADDRESS:32400/web
EOF

echo ''
echo "You need to manually enable remote management for Plex."
echo "Issue the following command on your LOCAL machine:"
echo "ssh $username@$ipaddr -L 8888:localhost:32400"
echo "open `localhost:8888/web` in a browser"
echo "Either login or create a new Plex account."
echo "Now enable remote access: Remote Access ->> Enable"
echo ''
echo "You should now be able to access plex at: $ipaddr:32400/web"
echo "Have you enabled remote access?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) ufw allow 8181; echo ''; echo "Cool, moving along."; echo ''; break;;
        No ) echo "You should really do that before continuing."; exit;;
    esac
done
