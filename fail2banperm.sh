#!/bin/bash

# Adds year-long ban for repeat offenders on SSH and WordPress (if WP filter is
# added) to standard Fail2Ban configuration.

cat <<EOF >> /etc/fail2ban/jail.local

[ssh-repeater]
enabled	= true
port	= ssh
filter	= sshd
action	= iptables-repeater[name=ssh]
	  sendmail-whois[name=SSH-repeater, dest=root, sender=root]
logpath = /var/log/auth.log
maxretry = 25
findtime = 31536000
bantime	= 31536000

# This section is needed if wp-fail2ban is installed as a plugin on WordPress
# [wordpress-auth-repeater]
# enabled = true
# port = http,https
# filter = wordpress
# action = iptables-repeater[name=wordpress]
#	   sendmail-whois[name=wordpress-repeater, dest=root, sender=root]
# logpath = /var/log/auth.log
# maxretry = 35
# findtime = 31536000
# bantime = 31536000
EOF

cat <<endOfFile > /etc/fail2ban/action.d/iptables-repeater.conf
# Fail2ban configuration file
#
# Author: Phil Hagen <phil@identityvector.com>
#

[Definition]

# Option: actionstart
# Notes.: command executed once at the start of Fail2Ban.
# Values: CMD
#
actionstart = iptables -N fail2ban-REPEAT-<name>
	      iptables -A fail2ban-REPEAT-<name> -j RETURN
	      iptables -I INPUT -j fail2ban-REPEAT-<name>
	      # set up from the static file
	      cat /etc/fail2ban/ip.blocklist.<name> | grep -v ^\s*# | awk '{print \$1}' | while read IP; do iptables -I fail2ban-REPEAT-<name> 1 -s \$IP -j DROP; done

# Option: actionstop
# Notes.: command executed once at the end of Fail2Ban
# Values: CMD
#
actionstop = iptables -D INPUT -j fail2ban-REPEAT-<name>
	     iptables -F fail2ban-REPEAT-<name>
	     iptables -X fail2ban-REPEAT-<name>

# Option: actioncheck
# Notes.: command executed once before each actionban command
# Values: CMD
actioncheck = iptables -n -L INPUT | grep -q fail2ban-REPEAT-<name>

# Option: actionban
# Notes.: command executed when banning an IP. Take care that the
#	  command is executed with Fail2Ban user rights.
# Tags:	  <ip> IP address
#	  <failures> number of failures
#	  <time> unix timestamp of the ban time
# Values: CMD
#
actionban = iptables -I fail2ban-REPEAT-<name> 1 -s <ip> -j DROP
	    # also put into the static file to re-populate after a restart
	    ! grep -Fq <ip> /etc/fail2ban/ip.blocklist.<name> && echo "<ip> # fail2ban/\$( date '+%%Y-%%m-%%d %%T' ): auto-add for repeat offender" >> /etc/fail2ban/ip.blocklist.<name>

# Option: actionunban
# Notes.: command executed when unbanning an IP. Take care that the
#	  command is executed with Fail2Ban user rights.
# Tags:	  <ip> IP address
#	  <failures> number of failures
#	  <time> unix timestamp of the ban time
# Values: CMD
#
actionunban = /bin/true

[Init]

# Default name of the chain
#
name = REPEAT
endOfFile

service fail2ban restart
