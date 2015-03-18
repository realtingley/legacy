#!/bin/bash

# Disable IPv6
cat <<END >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
END

# Allow Nagios through the firewall
iptables -I INPUT -p tcp -m tcp --dport 5666 -j ACCEPT

# Install repo packages that will be needed
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean false | debconf-set-selections
apt-get install -y libssl-dev iptables-persistent make xinetd

# Downloading, compiling, installing
mkdir ~/downloads
cd ~/downloads
wget http://nagios-plugins.org/download/nagios-plugins-2.0.3.tar.gz
tar xzf nagios-plugins-2.0.3.tar.gz
cd nagios-plugins-2.0.3
./configure
make
make install
chown nagios:nagios /usr/local/nagios
chown -R nagios:nagios /usr/local/nagios/libexec
cd ~/downloads
wget http://sourceforge.net/projects/nagios/files/nrpe-2.x/nrpe-2.15/nrpe-2.15.tar.gz
tar xzf nrpe-2.15.tar.gz
cd nrpe-2.15
./configure --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu
make all
make install-plugin
make install-daemon
make install-daemon-config
make install-xinetd
echo 'Now edit /etc/xinetd.d/nrpe for theh only_from directive.'
echo 'Then check for nrpe 5666/tcp in /etc/services.'
echo 'Restart xinetd.'
echo 'netstat -at | grep nrpe'
echo '/usr/local/nagios/libexec/check_nrpe -H HOSTNAME'
exit 0
