#!/bin/bash

sudo firewall-cmd --zone=libvirt --add-port=80/tcp
sudo firewall-cmd --zone=libvirt --add-port=80/tcp --permanent
sudo firewall-cmd --zone=libvirt --add-port=6230-6235/udp
sudo firewall-cmd --zone=libvirt --add-port=6230-6235/udp --permanent
sudo ps -ef | grep -q vbmcd 
if [ "$?" != "0" ] ; then 
  alias vbmcd='sudo podman run -d --name vbmcd  -p 6230:6230/udp -p 6231:6231/udp -p 6232:6232/udp -v /root/.vbmc:/root/.vbmc -v /var/run/libvirt:/var/run/libvirt karmab/virtualbmc-libvirt --foreground'
  alias vbmc='sudo podman exec vbmcd vbmc'
  shopt -s expand_aliases
  vbmcd > /dev/null 2>&1
fi
for num in $(seq 0 2) ; do
 sudo ls /root/.vbmc/openshift_master_$num > /dev/null 2>&1
 if [ "$?" != "0" ] ; then 
   sudo iptables -A INPUT -p udp --dport 623$num -j ACCEPT
   vbmc add openshift-master-$num --port 623$num --username admin --password password --libvirt-uri qemu:///system
   vbmc start openshift-master-$num
 fi
done
