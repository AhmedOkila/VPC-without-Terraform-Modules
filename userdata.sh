#!/bin/bash
apt update
apt install -y apache2
# Get the instance ID using the instance metadata
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id -H "X-aws-ec2-metadata-token: $TOKEN") 
echo "<center><h1>The Instance ID of this Amazon EC2 instance is: INSTANCE_ID </h1></center>" > /var/www/html/index.txt
sed "s/INSTANCE_ID/$INSTANCE_ID/" /var/www/html/index.txt > /var/www/html/index.html
# Start Apache and enable it on boot
systemctl start apache2
systemctl enable apache2
