#!/bin/bash

# Set the username and password for MySQL
USER="USERNAME"
PASS="PASSWORD"

# Backup MySQL databases for WordPress
mysqldump -u$USER -p$PASS --all-databases > /var/www/SITE/alldatabases.$(date +%F).sql | gzip > /var/www/SITE/alldatabases.$(date +%F).sql.gz
rm /var/www/SITE/alldatabases.$(date +%F).sql

# Remove MySQL backups that are over a month old from the /var/www/SITE/ directory
find /var/www/SITE/alldatabases.*.sql.gz -mtime +21 -exec rm {} \;

# Copy the directory to the EBS
mkdir -p /webdata/WPbackup/wordpress.$(date +%F).bak
cp -r /var/www/SITE/* /webdata/WPbackup/wordpress.$(date +%F).bak/

# Remove backups that are over a month old
find /webdata/WPbackup/* -mtime +21 -exec rm -r {} \;

exit 0

# EOF
