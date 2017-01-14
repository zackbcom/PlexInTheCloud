#!/bin/bash
source vars

# STRUCTURE!
rclone mkdir $encrypted:comics

# Install Dependencies
apt-get install -y default-jre

# Install Ubooquity
wget -O ubooquity.zip http://vaemendis.net/ubooquity/service/download.php
unzip ubooquity.zip -d /opt/ubooquity/
rm ubooquity.zip
chown -R $username:$username /opt/ubooquity

## Systemd Service File
tee "/etc/systemd/system/ubooquity.service" > /dev/null <<EOF
[Unit]
Description=Ubooquity
After=rcloneMount.service

[Service]
User=$username
Group=$username
WorkingDirectory=/opt/ubooquity
ExecStart=/usr/bin/java -jar /opt/ubooquity/Ubooquity.jar -headless -webadmin
Restart=always

[Install]
WantedBy=multi-user.target
EOF

## Start on Boot
systemctl daemon-reload
systemctl start ubooquity
systemctl enable ubooquity

echo ''
echo "Do you want to allow remote access to Ubooquity?"
echo "If so, you need to tell UFW to open the port."
echo "Otherwise, you can use SSH port forwarding."
echo ''
echo "Would you like us to open the port in UFW?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) ufw allow 2202; echo ''; echo "Port 2202 open, Ubooquity is now available over the internet."; echo ''; break;;
        No ) echo "Port 2202 left closed. You can still access it on your local machine by issuing the following command: ssh $username@$ipaddr -L 2202:localhost:2202"; echo "and then open localhost:2202 on your browser."; exit;;
    esac
done
