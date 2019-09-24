#!/bin/bash

# set some printing colors
RED='\033[0;31m'
BLUE='\033[0;36m'
NC='\033[0m'

which kcli >/dev/null 2>&1
BIN="$?"
alias kcli >/dev/null 2>&1
ALIAS="$?"

if [ "$BIN" != "0" ] && [ "$ALIAS" != "0" ]; then
  engine="docker"
  which podman >/dev/null 2>&1 && engine="podman"
  VOLUMES=""
  [ -d /var/lib/libvirt/images ] && [ -d /var/run/libvirt ] && VOLUMES="-v /var/lib/libvirt/images:/var/lib/libvirt/images -v /var/run/libvirt:/var/run/libvirt"
  [ -d $HOME/.kcli ] || mkdir -p $HOME/.kcli
  alias kcli="$engine run --net host -it --rm --security-opt label=disable -v $HOME/.kcli:/root/.kcli $VOLUMES -v $PWD:/workdir -v /tmp:/ignitiondir karmab/kcli"
  echo -e "${BLUE}Using $(alias kcli)${NC}"
fi

shopt -s expand_aliases
export cluster="${cluster:-ostest}"
export domain="${domain:-test.metalkube.org}"
if [ ! -f ~/.ssh/id_rsa.pub ] ; then
  echo -e "${RED}Missing ~/.ssh/id_rsa.pub${NC}"
  exit 1
fi
export ssh_key=$(cat ~/.ssh/id_rsa.pub)
if [ ! -f openshift_pull.json ] ; then
  echo -e "${RED}Missing openshift_pull.json${NC}"
  exit 1
fi
pull_secret=$(cat openshift_pull.json | tr -d [:space:])
external_bridge=baremetal
cidr="192.168.111.0/24"
dns_vip="192.168.111.3"
ingress_vip="192.168.111.4"
api_vip="192.168.111.5"
masters="${masters:-1}"
workers="${workers:-1}"
uri="$(kcli report | grep Connect | sed 's/Connection: //')"
kcli plan -f metal3.yml -P external_bridge=${external_bridge} -P masters=${masters} -P workers=${workers} metal3
kcli render -f install-config.yaml.j2 -P masters=$masters -P workers=$workers -P domain=$domain -P cluster=$cluster -P external_bridge=$external_bridge -P pull_secret="$pull_secret" -P ssh_key="${ssh_key}" -P uri="$uri"> install-config.yaml
kcli render -f config.sh.j2 -P pull_secret="$pull_secret" > install-config.yaml
