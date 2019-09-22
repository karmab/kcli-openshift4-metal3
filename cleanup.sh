
# set some printing colors
RED='\033[0;31m'
BLUE='\033[0;36m'
NC='\033[0m'

alias kcli='sudo podman run -it --rm -v /var/run/libvirt:/var/run/libvirt -v $PWD:/workdir karmab/kcli'
shopt -s expand_aliases
sudo podman rm -f vbmcd
kcli plan -d metal3 --yes
[ -d ocp ] && ocp/openshift-baremetal-install destroy cluster --log-level info --dir ocp
bootstrap=$(kcli list | grep bootstrap | awk -F'|' '{print $2}')
if [ "$bootstrap" != "" ] ; then
  kcli delete --yes $bootstrap
fi
[ -d ocp ] && rm -Rf ./ocp
