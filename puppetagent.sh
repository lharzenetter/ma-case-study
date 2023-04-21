#!/bin/bash

if [ -z "$IP" ]; then
    echo "Please provide an evironment var IP!"
    exit 1;
else
    echo "IP is: $IP"
fi

if [ -z "$PuppetMaster" ]; then
    echo "Please provide the IP of the PuppetMaster!"
    exit 1;
else
    echo "PuppetMaster IP is: $PuppetMaster"
fi

if [ -z "$puppetDNS" ]; then
    puppetDNS="puppet-master.test.com"
fi

if [ -z "$agentName" ]; then
    agentName="puppet-agent"
fi

echo "Using DNS: $puppetDNS"

sudo -E echo "
# Puppet
127.0.1.1 test
$IP puppet-agent
$PuppetMaster puppet $puppetDNS
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

wget "https://apt.puppetlabs.com/puppet6-release-${lsb_release}.deb"
sudo dpkg -i puppet6-release-${lsb_release}.deb
sudo apt-get update
sudo apt-get install -y puppet-agent

sudo -E echo "
[main]
certname    = $agentName
server      = $puppetDNS
environment = production
runinterval = 1y
" >> /etc/puppetlabs/puppet/puppet.conf

echo "Configured Puppet. Starting it now..."

sudo /opt/puppetlabs/bin/puppet resource service puppet ensure=running enable=true
