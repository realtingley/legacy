#!/bin/bash

tempfile="/tmp/ip.blocklist.ssh"
resultfile="/tmp/$HOSTNAME.blocklist.results"
IP=""
cp /etc/fail2ban/ip.blocklist.ssh $tempfile
while read IP; do
    echo $IP  | head -n1 | awk '{print $1 "\t"$3;}' | awk '{gsub("fail2ban/", "");print}'
done <$tempfile > $resultfile
scp -i /home/ubuntu/.ssh/apache1/id_rsa $resultfile USER@HOST:/tmp/
ssh -i /home/ubuntu/.ssh/apache1/id_rsa USER@HOST "cat $resultfile >> /home/USER/Documents/IT/bannedips.txt"
