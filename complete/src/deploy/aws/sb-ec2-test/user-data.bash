#!/bin/bash

/usr/bin/yum -y install java-1.8.0
/usr/sbin/alternatives --set java /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/java

mkdir /app
sudo mkfs -t ext4 /dev/xvdh
mount /dev/xvdh /app
chown ec2-user:ec2-user /app

cd /home/ec2-user
sudo -bn -u ec2-user -s /usr/bin/java -jar gs-accessing-data-rest-0.1.0.jar 2>&1 > gs-accessing-data-rest-0.1.0.log
chown ec2-user:ec2-user gs-accessing-data-rest-0.1.0.log