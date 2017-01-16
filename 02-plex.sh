#!/bin/bash
source vars

## INFO
# This script installs and configures Plex.
##

#######################
# Install
#######################
wget https://downloads.plex.tv/plex-media-server/1.3.3.3148-b38628e/plexmediaserver_1.3.3.3148-b38628e_amd64.deb
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
echo 'open localhost:8888/web in a browser'
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
