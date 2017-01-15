#!/bin/bash
source vars

## INFO
# This script installs and configures couchpotato
##

#######################
# Dependencies
#######################
apt-get install -y git-core libffi-dev libssl-dev zlib1g-dev libxslt1-dev libxml2-dev python python-pip python-dev build-essential

pip install lxml cryptography pyopenssl

#######################
# Install
#######################
git clone https://github.com/CouchPotato/CouchPotatoServer.git /opt/couchpotato/
chown -R $username:$username /opt/couchpotato

#######################
# Configure
#######################
## Write CouchPotato API to nzbget.conf so it can send post-processing requests
### Copy the api key from the CP config file
cpAPI=$(cat /home/$username/.couchpotato/settings.conf | grep "api_key = ................................" | cut -d= -f 2)

### Cut the single blank space that always gets added to the front of $cpAPI
cpAPInew="$(sed -e 's/[[:space:]]*$//' <<<${cpAPI})"

### Write the API key to nzbget.conf
sed -i "s/^nzbToCouchPotato.py:cpsapikey=.*/nzbToCouchPotato.py:cpsapikey=$cpAPInew/g" /opt/nzbget/nzbget.conf

## Configure CouchPotato
### CouchPotato stores our passwords as md5sum hashes...heh heh heh
cppassword=$(echo -n $passwd | md5sum | cut -d ' ' -f 1)
sed -i "s/^username =.*/username = $username/g" /home/$username/.couchpotato/settings.conf
sed -i "s/^password =.*/password = $cppassword/g" /home/$username/.couchpotato/settings.conf

### nzbget
sed -i "s/^username = nzbget/username = $username/g" /home/$username/.couchpotato/settings.conf
sed -i "s/^category = Movies/category = movies/g" /home/$username/.couchpotato/settings.conf

perl -i -0pe "s/username = nzbget\ncategory = Movies\ndelete_failed = True\nmanual = 0\nenabled = 0\npriority = 0\nssl = 0/username = $username\ncategory = movies\ndelete_failed = True\nmanual = 0\nenabled = 1\npriority = 0\n ssl = 0/" /home/$username/.couchpotato/settings.conf
perl -i -0pe "s/6789\npassword =/6789\npassword = $cppasswd\n/" /home/$username/.couchpotato/settings.conf

## Post Processing
## NZBget
sed -i "s/^Category1.Name=.*/Category1.Name=movies/g" /opt/nzbget/nzbget.conf
sed -i "s|^Category1.DestDir=.*|Category1.DestDir=/home/$username/nzbget/completed/movies|g" /opt/nzbget/nzbget.conf
sed -i "s/^Category1.PostScript=.*/Category1.PostScript=nzbToCouchPotato.py, Logger.py, uploadMovies.sh/g" /opt/nzbget/nzbget.conf

# nzbToCouchPotato
sed -i 's/^nzbToCouchPotato.py:auto_update=.*/nzbToCouchPotato.py:auto_update=1/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToCouchPotato.py:cpsCategory=.*/nzbToCouchPotato.py:cpsCategory=movies/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToCouchPotato.py:cpsdelete_failed=.*/nzbToCouchPotato.py:cpsdelete_failed=1/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToCouchPotato.py:getSubs=.*/nzbToCouchPotato.py:getSubs=1/g' /opt/nzbget/nzbget.conf
sed -i "s/^nzbToCouchPotato.py:subLanguages=.*/nzbToCouchPotato.py:subLanguages=$openSubtitlesLang/g" /opt/nzbget/nzbget.conf
sed -i "s|^nzbToCouchPotato.py:cpswatch_dir=.*|nzbToCouchPotato.py:cpswatch_dir=/home/$username/nzbget/completed/movies|g" /opt/nzbget/nzbget.conf

#######################
# Structure
#######################
mkdir /home/$username/nzbget/completed/movies
mkdir /home/$username/$local/movies

#######################
# Helper Scripts
#######################
tee "/home/$username/nzbget/scripts/uploadMovies.sh" > /dev/null <<EOF
#!/bin/bash

#######################################
### NZBGET POST-PROCESSING SCRIPT   ###

# Rclone upload to Amazon Cloud Drive

# Wait for NZBget/Sickrage to finish moving files
sleep 10s

# Upload
rclone move -c /home/$username/$local/movies $encrypted:movies

# Tell Plex to update the Library
#wget http://localhost:32400/library/sections/3/refresh?X-Plex-Token=$plexToken

# Send PP Success code
exit 93
EOF

#######################
# Systemd Service File
#######################
tee "/etc/systemd/system/couchpotato.service" > /dev/null <<EOF
[Unit]
Description=CouchPotato application instance
After=rcloneMount.service

[Service]
ExecStart=/opt/couchpotato/CouchPotato.py
Type=simple
User=$username
Group=$username

[Install]
WantedBy=multi-user.target
EOF

#######################
# Permissions
#######################
chown -R $username:$username /home/$username/nzbget/completed/movies
chown -R $username:$username /home/$username/$local/movies
chmod +x /home/$username/nzbget/scripts/uploadMovies.sh
chown root:root /etc/systemd/system/couchpotato.service
chmod 644 /etc/systemd/system/couchpotato.service

#######################
# Autostart
#######################
systemctl daemon-reload
systemctl start couchpotato
systemctl enable couchpotato
systemctl restart couchpotato

#######################
# Remote Access
#######################
echo ''
echo "Do you want to allow remote access to CouchPotato?"
echo "If so, you need to tell UFW to open the port."
echo "Otherwise, you can use SSH port forwarding."
echo ''
echo "Would you like us to open the port in UFW?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) ufw allow 5050; echo ''; echo "Port 5050 open, CouchPotato is now available over the internet."; echo ''; break;;
        No ) echo "Port 5050 left closed. You can still access it from your local machine by issuing the following command: ssh $username@$ipaddr -L 5050:localhost:5050"; echo "and then open localhost:5050 on your browser."; exit;;
    esac
done
