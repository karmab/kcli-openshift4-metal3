git clone https://github.com/openshift-kni/install-scripts
cp config_$USER.sh install-scripts/Openshift
cp install-config.yaml install-scripts/Openshift
cd install-scripts/Openshift
bash 03_create_cluster.sh
