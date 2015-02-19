#!/bin/bash

#Enter a password to use before using the script (also on line 26)
MYSQLPASS=ENTER PASS HERE

# Install DebConf, HTTPD, PHP5
apt-get update && apt-get -y install debconf-utils apache2 php5 libapache2-mod-php5 php5-mcrypt expect

# Configure PHP5
sed -i -e 's/.*DirectoryIndex.*/DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm/g' /etc/apache2/mods-enabled/dir.conf
sed -i -e 's/post_max_size = 8M/post_max_size = 20M/g'/etc/php5/apache2/php.ini
sed -i -e 's/upload_max_filesize = 2M/upload_max_filesize = 20M/g' /etc/php5/apache2/php.ini
sed -i -e 's/max_input_vars = 1000/max_input_vars = 5000/g' /etc/php5/apache2/php.ini

# Restart Apache HTTPD
service apache2 restart

# Install MySQL Server
echo mysql-server-5.5 mysql-server-5.5/root_password password $MYSQLPASS | debconf-set-selections
echo mysql-server-5.5 mysql-server-5.5/root_password_again password $MYSQLPASS | debconf-set-selections
apt-get -y install mysql-server libapache2-mod-auth-mysql php5-mysql

# Complete the MySQL installation
mysql_install_db

MYSQL_ROOT_PASSWORD=ENTER PASSWORD HERE
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"$MYSQLPASS\r\"

expect \"Change the root password?\"
send \"n\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"y\r\"

expect \"Remove test database and access to it?\"
send \"y\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
")

echo "$SECURE_MYSQL"

# Remove Expect
apt-get -y remove expect

# Restart Apache HTTPD one last time to make sure everything is running correctly
service apache2 restart

exit 0
