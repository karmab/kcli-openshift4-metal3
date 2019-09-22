# Baremetal ipi on a virtual env provisioned by kcli

Why? to deploy baremetal ipi on a node with the "bare" minimum

## Requirements

- an hypervisor with enough memory and disks
- libvirtd
- podman
- a valid pull secret

## Procedure

- copy your pull secret in a file named *openshift_pull.json*
- run the *vbmc.sh* script to launch vbmcd containers and create vbmc ports for your nodes
- run the *kcli.sh* script to create the networks and vms
- run the *deploy.sh* script to deploy openshift4 

## Cleaning

- run the *cleanup.sh* script
