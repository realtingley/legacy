#!/bin/bash

# Sort the list by IP and date #
sort -b -k2,2 -k1,1n /home/apache1/Documents/cssIT/bannedips.txt | sort -u -k1,1 | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n > /tmp/sorted.txt

# Look up country of origin, add to column three #
cat /tmp/sorted.txt | awk '{print $1}' > /tmp/readIP.txt
for ip in `cat /tmp/readIP.txt`; do
    country=$(curl -s ipinfo.io/$ip/country)
    echo -e "$ip \t $country" >> /tmp/writeCountry.txt
done
join /tmp/sorted.txt /tmp/writeCountry.txt > /tmp/bannedAddresses1.txt

# Convert to CSV #
tr ' ' ',' < /tmp/bannedAddresses1.txt > /tmp/bannedAddresses1.csv

# Convert country abbreviations to full names #
cat /tmp/bannedAddresses1.csv | while read line; do
  code=$(echo $line | awk '{print $3}' FS=,)
  cn=$(awk -v CID=$code '$2==CID {print $1}' FS=, /home/apache1/Documents/cssIT/countries.txt)
  echo $line | awk -v CN="$cn" 'BEGIN {FS=OFS=","}{$3=CN} 1' >> /tmp/bannedAddresses2.csv
done
rm -f /home/apache1/Desktop/bannedAddresses.csv
mv /tmp/bannedAddresses2.csv /home/apache1/Desktop/bannedAddresses.csv

# Analyze file for most frequent countries, blocks, etc.
# Finds 10 most common sources by country
cat /home/apache1/Desktop/bannedAddresses.csv | awk -F "," '{print $3}' | sort | uniq -c | sort -nr | head -10 > /home/apache1/Desktop/bannedDigest.txt
# Reports what percentage top source represents
# This is going to necessitate Python.

# Delete the temp files #
rm /tmp/sorted.txt /tmp/readIP.txt /tmp/writeCountry.txt /tmp/bannedAddresses1.txt /tmp/bannedAddresses1.csv

### IDEAS FOR LATER
# Function for identifying troublesome subnets
# Mark stuff older than a year somehow, or delete.