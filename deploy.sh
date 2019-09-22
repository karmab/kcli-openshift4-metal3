#!/bin/bash

# Ironic vars
export PULL_SECRET_FILE="${PULL_SECRET_FILE:-openshift_pull.json}"
export IRONIC_IMAGE=${IRONIC_IMAGE:-"quay.io/metal3-io/ironic:master"}
export COREOS_DOWNLOADER_IMAGE=${COREOS_DOWNLOADER_IMAGE:-"quay.io/openshift-metal3/rhcos-downloader:master"}
export CACHED_IMAGE_DIR="${SCRIPTDIR}/cache"
export PROVISIONING_INTERFACE="${PROVISIONING_INTERFACE:-ens3}"
export PROVISIONING_ADDRESS="172.22.0.3"
export CACHE_URL="http://172.22.0.1/images"

export KUBECONFIG="${PWD}/ocp/auth/kubeconfig"

if [ ! -d "${CACHED_IMAGE_DIR}" ]; then
  echo "Creating Cached Data Dir"
  sudo mkdir "${CACHED_IMAGE_DIR}"
  sudo chown "${USER}:${USER}" "${CACHED_IMAGE_DIR}"
  chmod 755 "${CACHED_IMAGE_DIR}"
fi

export OPENSHIFT_RELEASE_IMAGE="${OPENSHIFT_RELEASE_IMAGE:-registry.svc.ci.openshift.org/ocp/release:4.2}"
LOGLEVEL="${LOGLEVEL:-debug}"

export MOBY_DISABLE_PIGZ=true

function extract_command() {
    local release_image
    local cmd
    local outdir
    local extract_dir

    cmd="$1"
    release_image="$2"
    outdir="$3"

    extract_dir=$(mktemp -d "installer--XXXXXXXXXX")

    oc adm release extract --registry-config "${PULL_SECRET_FILE}" --command=$cmd --to "${extract_dir}" ${release_image}

    mv "${extract_dir}/${cmd}" "${outdir}"
    rm -rf "${extract_dir}"
}

# Let's always grab the `oc` from the release we're using.
function extract_oc() {
    extract_dir=$(mktemp -d "installer--XXXXXXXXXX")
    extract_command oc "$1" "${extract_dir}"
    sudo mv "${extract_dir}/oc" /usr/local/bin
    rm -rf "${extract_dir}"
}

function extract_installer() {
    local release_image
    local outdir

    release_image="$1"
    outdir="$2"

    extract_command openshift-baremetal-install "$1" "$2"
    export OPENSHIFT_INSTALLER="${outdir}/openshift-baremetal-install"
}

function rhcos_image_url() {
  #Dont do anything if there is a value already set
  if [[ -z "${RHCOS_IMAGE_URL}" ]]; then
    # Get the git commit that the openshift installer was built from
    OPENSHIFT_INSTALL_COMMIT=$($OPENSHIFT_INSTALLER version | grep commit | cut -d' ' -f4)

    # Get the rhcos.json for that commit
    OPENSHIFT_INSTALLER_RHCOS=${OPENSHIFT_INSTALLER_RHCOS:-https://raw.githubusercontent.com/openshift/installer/$OPENSHIFT_INSTALL_COMMIT/data/data/rhcos.json}

    # Get the rhcos.json for that commit, and find the baseURI and openstack image path
    RHCOS_IMAGE_JSON=$(curl "${OPENSHIFT_INSTALLER_RHCOS}")
    RHCOS_INSTALLER_IMAGE_URL=$(echo "${RHCOS_IMAGE_JSON}" | jq -r '.baseURI + .images.openstack.path')
    export RHCOS_IMAGE_URL=${RHCOS_IMAGE_URL:-${RHCOS_INSTALLER_IMAGE_URL}}
  fi
}

function cache_images() {
  
  # Either pull or build the ironic images
  # To build the IRONIC image set
  # IRONIC_IMAGE=https://github.com/metalkube/metalkube-ironic
  for IMAGE_VAR in IRONIC_IMAGE COREOS_DOWNLOADER_IMAGE ; do
      IMAGE=${!IMAGE_VAR}
      sudo podman pull "$IMAGE"
  done

  for name in httpd coreos-downloader; do
      sudo podman ps | grep -w "$name$" && sudo podman kill $name
      sudo podman ps --all | grep -w "$name$" && sudo podman rm $name -f
  done

  # Remove existing pod
  if  sudo podman pod exists ironic-pod ; then 
      sudo podman pod rm ironic-pod -f
  fi

  # Create pod
  sudo podman pod create -n ironic-pod 

  # We start only the httpd and *downloader containers so that we can provide
  # cached images to the bootstrap VM
  sudo podman run -d --net host --privileged --name httpd --pod ironic-pod \
     -v ${CACHED_IMAGE_DIR}:/shared --entrypoint /bin/runhttpd ${IRONIC_IMAGE}

  sudo podman run -d --net host --privileged --name coreos-downloader --pod ironic-pod \
     -v ${CACHED_IMAGE_DIR}:/shared ${COREOS_DOWNLOADER_IMAGE} /usr/local/bin/get-resource.sh ${RHCOS_IMAGE_URL}

  # Wait for the downloader containers to finish, if they are updating an existing cache
  # the checks below will pass because old data exists
  sudo podman wait -i 1000 coreos-downloader

  # Wait for images to be downloaded/ready
  while ! curl --fail http://localhost/images/rhcos-ootpa-latest.qcow2.md5sum ; do sleep 5 ; done
}

#To determine the image url, need the following extracted.
mkdir -p ocp
extract_oc ${OPENSHIFT_RELEASE_IMAGE}
extract_installer "${OPENSHIFT_RELEASE_IMAGE}" ocp/

# Discover and set RHCOS_IMAGE_URL
rhcos_image_url

if [[ ${CACHE_IMAGES^^} != "FALSE" ]]
then
    cache_images
fi

cp install-config.yaml ocp
LOGLEVEL="debug"
${OPENSHIFT_INSTALLER} --dir ocp --log-level=${LOGLEVEL} create manifests
envsubst < metal3-config-map.yaml > ocp/openshift/99-metal3-config-map.yaml
${OPENSHIFT_INSTALLER} --dir ocp --log-level=${LOGLEVEL} create cluster
