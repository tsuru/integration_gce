#!/bin/bash

set -e

if [[ "$GCE_SERVICE_ACCOUNT" == "" ]] ||
  [[ "$GCE_PROJECT_ID" == "" ]] ||
  [[ "$GCE_ZONE" == "" ]]; then
  echo "Missing required envs"
  exit 1
fi

export GCE_MACHINE_TYPE=n1-standard-4
TSURUVERSION=${TSURUVERSION:-latest}

tmpdir=$(mktemp -d)
gcefilename=$tmpdir/google-application-credentials
echo $GCE_SERVICE_ACCOUNT > $gcefilename
export GOOGLE_APPLICATION_CREDENTIALS=$gcefilename

function cleanup() {
  sudo apt-get update -y && sudo apt-get install lsb-release -y
  CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
  echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  sudo apt-get update -y && sudo apt-get install google-cloud-sdk -y

  export CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE=$gcefilename
  gcloud config set project $GCE_PROJECT_ID
  gcloud config set compute/zone $GCE_ZONE

  clusters=$(gcloud container clusters list --format json | jq -r '.[].name | select(. | contains("icluster-kube-"))')
  instances=$(gcloud compute instances list --filter "tags:docker-machine" --format json | jq -r '.[].name')
  if [ ! -z "$clusters" ]; then
    gcloud container clusters delete -q $clusters
  fi
  if [ ! -z "$instances" ]; then
    gcloud compute instances delete --delete-disks=all -q $instances
  fi
}

if which apt-get; then
  cleanup
  trap cleanup EXIT
fi

echo "Going to test tsuru image version: $TSURUVERSION"

function abspath() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
mypath=$(abspath $(dirname ${BASH_SOURCE[0]}))
finalconfigpath=$(mktemp)
cp ${mypath}/config.yml ${finalconfigpath}
instancename=$(echo "integration-test-$RANDOM")
sed -i.bak "s|\$GCE_INSTANCE_NAME|${instancename}|g" ${finalconfigpath}
sed -i.bak "s|\$GCE_PROJECT_ID|${GCE_PROJECT_ID}|g" ${finalconfigpath}
sed -i.bak "s|\$GCE_ZONE|${GCE_ZONE}|g" ${finalconfigpath}
sed -i.bak "s|\$GCE_MACHINE_TYPE|${GCE_MACHINE_TYPE}|g" ${finalconfigpath}
sed -i.bak "s|\$TSURUVERSION|${TSURUVERSION}|g" ${finalconfigpath}

export GO111MODULE=on
export GOPATH=${tmpdir}
export PATH=$GOPATH/bin:$PATH
echo "Go get platforms..."
go get -d github.com/tsuru/platforms/examples/go
echo "Go get tsuru..."
go get github.com/tsuru/tsuru/integration
echo "Go get tsuru client..."
go get -d github.com/tsuru/tsuru-client/tsuru
pushd $GOPATH/src/github.com/tsuru/tsuru-client
if [ "$TSURUVERSION" != "latest" ]; then
  MINOR=$(echo "$TSURUVERSION" | sed -E 's/^[^0-9]*([0-9]+\.[0-9]+).*$/\1/g')
  CLIENT_TAG=$(git tag --list "$MINOR.*" --sort=-taggerdate | head -1)
  if [ "$CLIENT_TAG" != "" ]; then
    echo "Checking out tsuru-client $CLIENT_TAG"
    git checkout $CLIENT_TAG
  fi
fi
go install ./...
popd
pushd $GOPATH/src/github.com/tsuru/tsuru

export TSURU_INTEGRATION_installername=$instancename
if [ -z $TSURU_INTEGRATION_clusters ]; then
  export TSURU_INTEGRATION_clusters="gke"
fi
export TSURU_INTEGRATION_examplesdir="${GOPATH}/src/github.com/tsuru/platforms/examples"
export TSURU_INTEGRATION_installerconfig=${finalconfigpath}
export TSURU_INTEGRATION_nodeopts="iaas=dockermachine"
export TSURU_INTEGRATION_maxconcurrency=4
export TSURU_INTEGRATION_enabled=1
if [ -z $TSURU_INTEGRATION_verbose ]; then
  export TSURU_INTEGRATION_verbose=1
fi

go test -v -timeout 120m ./integration

rm -f ${finalconfigpath}
