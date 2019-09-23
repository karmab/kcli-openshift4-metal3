# Baremetal ipi on a virtual env provisioned by kcli

Why? to deploy baremetal ipi on a node with the "bare" minimum

## Requirements

- an hypervisor with enough memory and disks
- libvirtd
- podman
- a valid pull secret stored in a file named *openshift_pull.json*

## Procedure

- define the following env variables to indicate how many masters and workers you want to deploy
  - masters
  - workers

- run the *vbmc.sh* script to launch vbmcd containers and create vbmc ports for your nodes
- run the *kcli.sh* script to create the networks and vms, and render the install-config.yaml
- run the *deploy.sh* script to deploy openshift4 

## Cleaning

- run the *cleanup.sh* script
