#!/bin/bash

which kcli >/dev/null 2>&1
BIN="$?"
alias kcli >/dev/null 2>&1
ALIAS="$?"

if [ "$BIN" != "0" ] && [ "$ALIAS" != "0" ]; then
  engine="docker"
  which podman >/dev/null 2>&1 && engine="podman"
  VOLUMES=""
  [ -d $HOME/.kcli ] || mkdir -p $HOME/.kcli
  alias kcli='$engine run --net host -it --rm -v $HOME/.kcli:/root/.kcli -v $PWD:/workdir karmab/kcli'
  echo -e "${BLUE}Using $(alias kcli)${NC}"
fi

shopt -s expand_aliases
export cluster="${cluster:-ostest}"
export domain="${domain:-test.metalkube.org}"
export ssh_key=$(cat ~/.ssh/id_rsa.pub)
if [ ! -f openshift_pull.json ] ; then
  echo -e "Missing openshift_pull.json"
  exit 1
fi
export pull_secret=$(cat openshift_pull.json | tr -d [:space:])
export external_bridge=baremetal
export cidr="192.168.111.0/24"
export dns_vip="192.168.111.3"
export ingress_vip="192.168.111.4"
export api_vip="192.168.111.5"
kcli plan -f metal3.yml -P external_bridge=${external_bridge} metal3
envsubst < install-config.templ.yaml > install-config.yaml
