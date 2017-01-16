#!/bin/bash
source vars

## INFO
# This script installs and configures sickrage
##

#######################
# Pre-Install
#######################
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Execute 'sudo su' to swap to the root user." 
   exit 1
fi

#######################
# Dependencies
#######################
apt-get install -y unrar-free git-core openssl libssl-dev python2.7

#######################
# Install
#######################
git clone https://github.com/SickRage/SickRage.git /opt/sickrage/

#######################
# Configure
#######################
sed -i "s/^tv_download_dir =.*/tv_download_dir = \/home\/$username\/nzbget\/completed\/tv/g" /opt/sickrage/config.ini
sed -i "s/^root_dirs =.*/root_dirs = 0|\/home\/$username\/$overlayfuse\/tv/g" /opt/sickrage/config.ini
sed -i "s|naming_pattern =.*|naming_pattern = Season %0S\\\%S_N-S%0SE%0E-%E_N-%Q_N|g" /opt/sickrage/config.ini

sed -i "s/^web_username =.*/web_username = $username/g" /opt/sickrage/config.ini
sed -i "s/^web_password =.*/web_password = $passwd/g" /opt/sickrage/config.ini

sed -i "s/^nzbget_username =.*/nzbget_username = $username/g" /opt/sickrage/config.ini
sed -i "s/^nzbget_password =.*/nzbget_password = $passwd/g" /opt/sickrage/config.ini

sed -i "s/^opensubtitles_password =.*/opensubtitles_password = $openSubtitlesPassword/g" /opt/sickrage/config.ini
sed -i "s/^opensubtitles_username =.*/opensubtitles_username = $openSubtitlesUsername/g" /opt/sickrage/config.ini
sed -i "s/^subtitles_languages =.*/subtitles_languages = $openSubtitlesLang/g" /opt/sickrage/config.ini

sed -i 's/^SUBTITLES_SERVICES_LIST =.*/SUBTITLES_SERVICES_LIST = "opensubtitles,addic7ed,legendastv,shooter,subscenter,thesubdb,tvsubtitles"/g' /opt/sickrage/config.ini
sed -i "s/^use_subtitles =.*/use_subtitles = 1/g" /opt/sickrage/config.ini
sed -i 's/^SUBTITLES_SERVICES_ENABLED =.*/SUBTITLES_SERVICES_ENABLED = 1|0|0|0|0|0|0|0|0/g' /opt/sickrage/config.ini

sed -i "s/^use_failed_downloads =.*/use_failed_downloads = 1/g" /opt/sickrage/config.ini
sed -i "s/^delete_failed =.*/delete_failed = 1/g" /opt/sickrage/config.ini

## Post-Processing
# nzbget
sed -i "s/^Category2.Name=.*/Category2.Name=tv/g" /opt/nzbget/nzbget.conf
sed -i "s|^Category2.DestDir=.*|Category2.DestDir=/home/$username/nzbget/completed/tv|g" /opt/nzbget/nzbget.conf
sed -i "s/^Category2.PostScript=.*/Category2.PostScript=nzbToSickBeard.py, Logger.py, uploadTV.sh/g" /opt/nzbget/nzbget.conf

# nzbToSickBeard
sed -i 's/^nzbToSickBeard.py:auto_update=.*/nzbToSickBeard.py:auto_update=1/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToSickBeard.py:sbCategory=.*/nzbToSickBeard.py:sbCategory=tv/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToSickBeard.py:sbdelete_failed=.*/nzbToSickBeard.py:sbdelete_failed=1/g' /opt/nzbget/nzbget.conf
sed -i 's/^nzbToSickBeard.py:getSubs=.*/nzbToSickBeard.py:getSubs=1/g' /opt/nzbget/nzbget.conf
sed -i "s/^nzbToSickBeard.py:subLanguages=.*/nzbToSickBeard.py:subLanguages=$openSubtitlesLang/g" /opt/nzbget/nzbget.conf
sed -i "s/^nzbToSickBeard.py:sbusername=.*/nzbToSickBeard.py:sbusername=$username/g" /opt/nzbget/nzbget.conf
sed -i "s/^nzbToSickBeard.py:sbpassword=.*/nzbToSickBeard.py:sbpassword=$passwd/g" /opt/nzbget/nzbget.conf
sed -i "s|^nzbToSickBeard.py:sbwatch_dir=.*|nzbToSickBeard.py:sbwatch_dir=/home/$username/nzbget/completed/tv|g" /opt/nzbget/nzbget.conf

#######################
# Helper Scripts
#######################
tee "/home/$username/nzbget/scripts/uploadTV.sh" > /dev/null <<EOF
#!/bin/bash

#######################################
### NZBGET POST-PROCESSING SCRIPT   ###

# Rclone upload to Amazon Cloud Drive

# Wait for NZBget/Sickrage to finish moving files
sleep 10s

# Upload
rclone move -c /home/$username/$local/tv $encrypted:tv

# Tell Plex to update the Library
#wget http://localhost:32400/library/sections/2/refresh?X-Plex-Token=$plexToken

# Send PP Success code
exit 93
EOF

#######################
# Systemd Service File
#######################
tee "/etc/systemd/system/sickrage.service" > /dev/null <<EOF
[Unit]
Description=SickRage Daemon
After=rcloneMount.service

[Service]
User=$username
Group=$username

Type=forking
GuessMainPID=no
ExecStart=/usr/bin/python2.7 /opt/sickrage/SickBeard.py -q --daemon --nolaunch --datadir=/opt/sickrage

[Install]
WantedBy=multi-user.target
EOF

#######################
# Permissions
#######################
chown -R $username:$username /opt/sickrage
chmod +x /home/$username/nzbget/scripts/uploadTV.sh
chown root:root /etc/systemd/system/sickrage.service
chmod 644 /etc/systemd/system/sickrage.service

#######################
# Autostart
#######################
systemctl daemon-reload
systemctl start sickrage
systemctl enable sickrage

#######################
# Remote Access
#######################
echo ''
echo "Do you want to allow remote access to Sickrage?"
echo "If so, you need to tell UFW to open the port."
echo "Otherwise, you can use SSH port forwarding."
echo ''
echo "Would you like us to open the port in UFW?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) ufw allow 8081; echo ''; echo "Port 8081 open, Sickrage is now available over the internet."; echo ''; break;;
        No ) echo "Port 8081 left closed. You can still access it on your local machine by issuing the following command: ssh $username@$ipaddr -L 8081:localhost:8081"; echo "and then open localhost:8081 on your browser."; exit;;
    esac
done
