#!/bin/bash

#If possible, add something in for choosing [1] Configure Basics [2] Configure Security [3] Configure VMware Tools [4] Configure All. This might require Perl.
#set -x
read -p "RUN AS SUDO This script will perform basic configuration, as well as security configuration. Please connect VMware Tools image to include in installation. THIS SCRIPT WILL REPLACE A LOT OF IMPORTANT FILES. Seriously. Run this only on new systems. Press [ENTER] to continue or ^C to exit."

read -p "Configure this server to be on 50.247.195.80/28?" yn
while true; do
case $yn in
	[Yy]* )
		echo "What IP address will be assigned to this server?"
		read ADDRESS
		cat <<EOF > /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
address $ADDRESS
netmask 255.255.255.240
gateway 50.247.195.94
dns-nameservers 8.8.8.8 8.8.4.4
EOF
		break;;
	[Nn]* ) break;;
	* ) echo "Please answer [y]es or [n]o." ;;
esac
done

# Update apt-get and upgrade any installed packages
apt-get update && apt-get -y dist-upgrade

# Install NTP, OpenSSH, Fail2Ban, PSAD
debconf-set-selections <<< "postfix postfix/main_mailer_type select No configuration"
apt-get install -y ntp openssh-server fail2ban psad

# Disable root login on SSH and decrease grace time
sed -i '/LoginGraceTime/ c\LoginGraceTime 60' /etc/ssh/sshd_config
sed -i '/PermitRootLogin/ c\PermitRootLogin no' /etc/ssh/sshd_config
sed -i '/StrictModes/ c\StrictModes yes' /etc/ssh/sshd_config
service ssh restart

# Disable IPv6
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf

# Log martians, deny ICMP routing
sed -i '/net.ipv4.conf.all.log_martians/ c\net.ipv4.conf.all.log_martians = 1' /etc/sysctl.conf
sed -i '/net.ipv4.conf.all.accept_source_route/ c\net.ipv4.conf.all.accept_source_route = 0' /etc/sysctl.conf
sed -i '/net.ipv4.conf.all.send_redirects/ c\net.ipv4.conf.all.send_redirects = 0' /etc/sysctl.conf
sed -i '/net.ipv4.conf.all.accept_redirects/ c\net.ipv4.conf.all.accept_redirects = 0' /etc/sysctl.conf

# Configure the firewall
iptables -F
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
#iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
iptables -I INPUT 1 -i lo -j ACCEPT
iptables -P INPUT DROP
iptables -A INPUT -j LOG
iptables -A FORWARD -j LOG
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt-get install -y iptables-persistent

# Fail2Ban Configuration
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i '21s/.*/ignoreip = 127.0.0.1\/8 192.168.0.0\/16 50.247.195.80\/28/' /etc/fail2ban/jail.local
sed -i '22s/600/1800/' /etc/fail2ban/jail.local
sed -i '23s/.*/maxretry = 5/' /etc/fail2ban/jail.local
sed -i '24s/.*/findtime = 1200/' /etc/fail2ban/jail.local
sed -i '99s/6/5/' /etc/fail2ban/jail.local
cat <<EOF >> /etc/fail2ban/jail.local

[ssh-repeater]
enabled	= true
port	= ssh
filter	= sshd
action	= iptables-repeater[name=ssh]
		  sendmail-whois[name=SSH-repeater, dest=root, sender=root]
logpath	= /var/log/auth.log
maxretry = 25
findtime = 31536000
bantime	= 31536000

# This section is needed if wp-fail2ban is installed as a plugin on Wordpress
#[wordpress-auth-repeater]
#enabled	= true
#port	= http,https
#filter	= wordpress
#action	= iptables-repeater[name=wordpress]
#		  sendmail-whois[name=wordpress-repeater, dest=root, sender=root]
#logpath	= /var/log/auth.log
#maxretry = 35
#findtime = 31536000
#bantime = 31536000
EOF
touch /etc/fail2ban/action.d/iptables-repeater.conf
cat <<endOFfile > /etc/fail2ban/action.d/iptables-repeater.conf
# Fail2ban configuration file
#
# Author: Phil Hagen <phil@identityvector.com>
#

[Definition]

# Option:  actionstart
# Notes.:  command executed once at the start of Fail2Ban.
# Values:  CMD
#
actionstart = iptables -N fail2ban-REPEAT-<name>
              iptables -A fail2ban-REPEAT-<name> -j RETURN
              iptables -I INPUT -j fail2ban-REPEAT-<name>
              # set up from the static file
              cat /etc/fail2ban/ip.blocklist.<name> |grep -v ^\s*#|awk '{print $1}' | while read IP; do iptables -I fail2ban-REPEAT-<name> 1 -s $IP -j DROP; done

# Option:  actionstop
# Notes.:  command executed once at the end of Fail2Ban
# Values:  CMD
#
actionstop = iptables -D INPUT -j fail2ban-REPEAT-<name>
             iptables -F fail2ban-REPEAT-<name>
             iptables -X fail2ban-REPEAT-<name>

# Option:  actioncheck
# Notes.:  command executed once before each actionban command
# Values:  CMD
#
actioncheck = iptables -n -L INPUT | grep -q fail2ban-REPEAT-<name>

# Option:  actionban
# Notes.:  command executed when banning an IP. Take care that the
#          command is executed with Fail2Ban user rights.
# Tags:    <ip>  IP address
#          <failures>  number of failures
#          <time>  unix timestamp of the ban time
# Values:  CMD
#
actionban = iptables -I fail2ban-REPEAT-<name> 1 -s <ip> -j DROP
            # also put into the static file to re-populate after a restart
            ! grep -Fq <ip> /etc/fail2ban/ip.blocklist.<name> && echo "<ip> # fail2ban/$( date '+%%Y-%%m-%%d %%T' ): auto-add for repeat offender" >> /etc/fail2ban/ip.blocklist.<name>

# Option:  actionunban
# Notes.:  command executed when unbanning an IP. Take care that the
#          command is executed with Fail2Ban user rights.
# Tags:    <ip>  IP address
#          <failures>  number of failures
#          <time>  unix timestamp of the ban time
# Values:  CMD
#
actionunban = /bin/true

[Init]

# Defaut name of the chain
#
name = REPEAT
endOFfile
service fail2ban restart

# PSAD Configuration
cp /etc/psad/psad.conf /etc/psad/psad.conf.orig
sed -i "s/_CHANGEME_;/${HOSTNAME};/" /etc/psad/psad.conf
sed -i 's/HOME_NET                    any;/HOME_NET                    50.247.195.80\/28;/' /etc/psad/psad.conf
sed -i 's/var\/log\/messages/var\/log\/syslog/' /etc/psad/psad.conf
sed -i '/ENABLE_AUTO_IDS             N;/ c\ENABLE_AUTO_IDS             Y;' /etc/psad/psad.conf
sed -i '/AUTO_IDS_DANGER_LEVEL/ c\AUTO_IDS_DANGER_LEVEL 4;' /etc/psad/psad.conf
echo '127.0.0.0/8 0;' >> /etc/psad/auto_dl
echo '50.247.195.80/28 0;' >> /etc/psad/auto_dl
psad --sig-update
service psad restart

# Add psad sig-update to weekly root crontab
crontab -l > /tmp/mycron
echo '00 06 * * 1 psad --sig-update' >> /tmp/mycron
crontab /tmp/mycron
rm /tmp/mycron

# VMware Tools install
mkdir /mnt/cdrom
mount /dev/cdrom /mnt/cdrom
VMWT=$(ls /mnt/cdrom/ | grep VMwareTools*)
tar xzvf /mnt/cdrom/$VMWT -C /tmp/
/tmp/vmware-tools-distrib/vmware-install.pl -d

# Reminder to install VMware Tools
echo "Remember to install VMware Tools if you didn't!"

exit 0
