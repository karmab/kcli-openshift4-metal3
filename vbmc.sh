#!/bin/bash

masters="${masters:-1}"
workers="${workers:-1}"
sudo firewall-cmd --zone=libvirt --add-port=80/tcp >/dev/null 2>&1
sudo firewall-cmd --zone=libvirt --add-port=80/tcp --permanent >/dev/null 2>&1
sudo firewall-cmd --zone=libvirt --add-port=6230-6235/udp >/dev/null 2>&1
sudo firewall-cmd --zone=libvirt --add-port=6230-6235/udp --permanent >/dev/null 2>&1
sudo mkdir /root/.vbmc 2>/dev/null || true
alias vbmcd='sudo podman run -d --name vbmcd  -p 6230:6230/udp -p 6231:6231/udp -p 6232:6232/udp -v /root/.vbmc:/root/.vbmc -v /var/run/libvirt:/var/run/libvirt karmab/virtualbmc-libvirt --foreground'
alias vbmc='sudo podman exec vbmcd vbmc'
shopt -s expand_aliases
vbmcd > /dev/null 2>&1
allmasters=$(( $masters -1 ))
for num in $(seq 0 $allmasters) ; do
 sudo ls /root/.vbmc/openshift-master-$num > /dev/null 2>&1
 if [ "$?" != "0" ] ; then 
   sudo iptables -A INPUT -p udp --dport 623$num -j ACCEPT
   vbmc add openshift-master-$num --port 623$num --username admin --password password --libvirt-uri qemu:///system
   vbmc start openshift-master-$num
 fi
done
allworkers=$(( $workers -1 ))
for num in $(seq 0 $allworkers) ; do
 sudo ls /root/.vbmc/openshift-workers-$num > /dev/null 2>&1
 if [ "$?" != "0" ] ; then 
   sudo iptables -A INPUT -p udp --dport 624$num -j ACCEPT
   vbmc add openshift-worker-$num --port 624$num --username admin --password password --libvirt-uri qemu:///system
   vbmc start openshift-worker-$num
 fi
done
