alias kcli='sudo podman run -it --rm -v /var/run/libvirt:/var/run/libvirt -v $PWD:/workdir karmab/kcli'
shopt -s expand_aliases
sudo podman rm -f vbmcd
kcli plan -d metal3 --yes
ocp/openshift-baremetal-install destroy cluster --log-level info --dir ocp
kcli delete --yes $(kcli list | grep bootstrap | awk -F'|' '{print $2}')
[-d ocp ] && rm -Rf ./ocp
