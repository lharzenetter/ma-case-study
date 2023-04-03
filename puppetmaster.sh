#!/bin/bash

if [ -z "$IP" ]; then
    echo "Please provide an evironment var IP!"
    exit 1;
else
    echo "IP is: $IP"
fi

if [ -z "$puppetDNS" ]; then
    puppetDNS="puppet-master.test.com"
fi

echo "Using DNS: $puppetDNS"

sudo -E echo "
# Puppet
127.0.1.1 localhost
$IP puppet $puppetDNS
" >> /etc/hosts

echo "Updated hosts file!"

echo "Starting to install Puppet"
sudo apt-get update

command -v wget > /dev/null 2>&1 || {
    sudo apt-get install wget -y > /dev/null 2>&1
}

lsb_release=$(awk -F"=" '/VERSION_CODENAME=/ {print $2}' /etc/os-release)

export DEBIAN_FRONTEND="noninteractive" TZ="UTC"
echo "Europe/Berlin" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

wget "https://apt.puppetlabs.com/puppet7-release-${lsb_release}.deb"
sudo dpkg -i puppet7-release-${lsb_release}.deb
#sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt ${lsb_release}-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
#wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo -E apt -y install postgresql puppetserver

echo "Installed Puppet"

echo "Starting to configure it..."

sudo -E echo "
[main]
certname    = $puppetDNS
server      = $puppetDNS
environment = production
runinterval = 1y
" >> /etc/puppetlabs/puppet/puppet.conf

sudo /opt/puppetlabs/bin/puppetserver ca setup


echo "Starting the Puppet service now..."
#sudo systemctl enable puppetserver
#sudo systemctl start puppetserver
sudo service puppetserver start

echo "Installing the Puppet DB..."
sudo /opt/puppetlabs/bin/puppet resource package puppetdb ensure=latest
sudo /opt/puppetlabs/bin/puppet resource package puppetdb-termini ensure=latest

sudo -E echo "[main]
server_urls = https://puppet:8081
" > /etc/puppetlabs/puppet/puppetdb.conf

sudo -E echo "[database]
# The database address, i.e. //HOST:PORT/DATABASE_NAME
subname = //localhost:5432/puppetdb
# Connect as a specific user
username = puppetdb
# Use a specific password
password = puppetdb
# How often (in minutes) to compact the database
# gc-interval = 60
" > /etc/puppetlabs/puppetdb/conf.d/database.ini

sudo service postgresql start

sudo -E sed -ie "/\[main\]/i dns_alt_names        = puppet,$puppetDNS \n\
storeconfigs         = true \n\
storeconfigs_backend = puppetdb \n\
reports              = store,puppetdb \n" /etc/puppetlabs/puppet/puppet.conf

sudo echo "---
server:
  facts:
    terminus: puppetdb
    cache: yaml
" > /etc/puppetlabs/puppet/routes.yaml

echo "Setup Puppet to use Puppet DB!" 

sudo -u postgres sh -c "createuser -DRSP puppetdb; createdb -E UTF8 -O puppetdb puppetdb; psql puppetdb -c 'create extension pg_trgm'"

echo "Created the PuppetDB in PostgreSQL"

sudo service postgresql restart
sudo /opt/puppetlabs/bin/puppet resource service puppetdb ensure=running enable=true

sudo kill -HUP `pgrep -f puppet-server`
sudo service puppetserver reload

echo "Done installing Puppet!"

sudo /opt/puppetlabs/bin/puppet module install puppetlabs-mysql --version 13.2.0
