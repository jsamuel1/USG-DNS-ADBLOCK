#!/bin/bash
#
#DNS adblock/malware block for USG
#
#Orginal script: https://community.ubnt.com/t5/UniFi-Routing-Switching/Use-USG-to-block-sites-apps-like-ER/td-p/1497045
#
#Howto: SSH into your USG:
#sudo su -
#vi /config/user-data/update-adblock-dnsmasq.sh (add file content)
#ESC :wq
#chmod +x /config/user-data/update-adblock-dnsmasq.sh
#/config/user-data/update-adblock-dnsmasq.sh
#
#check if all went fine by nslookup on a box that uses your USG as DNS (default from DHCP)
#>nslookup 01cn.net (should return address: 0.0.0.0)
#
#crontab -l should show you now a line to automatically update once a day
#
#enjoy!
if grep -q adblock /var/spool/cron/crontabs/root
then
  echo "Cron OK"
else
 echo "0 3 * * 0 /config/user-data/update-adblock-dnsmasq.sh" >> /var/spool/cron/crontabs/root
fi

# Blocklist for ads
blocklist_url1_1="https://pgl.yoyo.org/adservers/serverlist.php?hostformat=dnsmasq&showintro=0&mimetype=plaintext"
# Blocklist for malware
blocklist_url2_1="https://www.dshield.org/feeds/suspiciousdomains_High.txt"
blocklist_url2_2="https://www.dshield.org/feeds/suspiciousdomains_Medium.txt"
blocklist_url2_3="https://www.dshield.org/feeds/suspiciousdomains_Low.txt"

# IP to respond to DNS query if domain is on blocklist
# IP '0.0.0.0' is a black hole. Per RFC 1122, section 3.2.1.3 "This host on this network. MUST NOT be sent, except as a source address as part of an initialization procedure by which the host learns its own IP address."
pixelserv_ip="0.0.0.0"

# Block configuration to be used by dnsmasq
blocklist="/etc/dnsmasq.d/dnsmasq-blocklist.conf"

# Temp blocklists
temp_blocklist1="/tmp/dnsmasq-blocklist1.conf.tmp"
temp_blocklist2="/tmp/dnsmasq-blocklist2.conf.tmp"

curl -s $blocklist_url1_1 | sed "s/127\.0\.0\.1/$pixelserv_ip/" > $temp_blocklist1
curl -s $blocklist_url2_1 > $temp_blocklist2
curl -s $blocklist_url2_2 >> $temp_blocklist2
curl -s $blocklist_url2_3 >> $temp_blocklist2

# Remove comment lines
sed -i "/^#/d" $temp_blocklist2
# Remove header line: Site
sed -i "/Site/d" $temp_blocklist2
# Add to start of all lines: /address=
sed -i "s/^/address=\//g" $temp_blocklist2
# Add to end of all lines: /$pixelserv_ip
sed -i "s/$/\/$pixelserv_ip/" $temp_blocklist2

# Join files to one
cat $temp_blocklist2 >> $temp_blocklist1

# If temp blocklist exists
if [ -f "$temp_blocklist1" ]
then
# sort ad blocking list in the temp file and remove duplicate lines from it
 sort -o $temp_blocklist1 -t '/' -uk2 $temp_blocklist1

# uncomment the line below, and modify it to remove your favorite sites from the ad blocking list
 sed -i -e '/spclient\.wg\.spotify\.com/d' $temp_blocklist1
 sed -i -e '/paperlesspost\.com/d' $temp_blocklist1
 sed -i -e '/grouptogether\.com/d' $temp_blocklist1
 sed -i -e '/evite\.com/d' $temp_blocklist1
 sed -i -e '/analytics\.twitter\.com/d' $temp_blocklist1
 # required for taste.com.au
 sed -i -e '/tags\.news\.com\.au/d' $temp_blocklist1 

 # Keep only unique entries
 sort $temp_blocklist1 | uniq > $blocklist
else
 echo "Error building the ad list, please try again."
 exit
fi

#ensure no temporary files left over, or DNS will be overloaded with too many entries.
rm -f /etc/dnsmasq.d/*.tmp
rm -f /etc/dnsmasq.d/sed*
rm -f $tmp_blocklist1
rm -f $tmp_blocklist2

#
## restart dnsmasq
/etc/init.d/dnsmasq force-reload
