#!/bin/bash

set -e

TSURUVERSION=${TSURUVERSION:-latest}

echo "Going to test tsuru image version: $TSURUVERSION"

function abspath() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
mypath=$(abspath $(dirname ${BASH_SOURCE[0]}))
finalconfigpath=$(mktemp)
cp ${mypath}/config.yml ${finalconfigpath}
instancename=$(echo "integration-test-$RANDOM")
sed -i.bak "s|\$GCE_INSTANCE_NAME|${instancename}|g" ${finalconfigpath}
sed -i.bak "s|\$GCE_PROJECT_ID|${GCE_PROJECT_ID}|g" ${finalconfigpath}
sed -i.bak "s|\$GCE_ZONE|${GCE_ZONE}|g" ${finalconfigpath}
sed -i.bak "s|\$TSURUVERSION|${TSURUVERSION}|g" ${finalconfigpath}

tmpdir=$(mktemp -d)
export GOPATH=${tmpdir}
export PATH=$GOPATH/bin:$PATH
echo "Go get platforms..."
go get github.com/tsuru/platforms/...
echo "Go get tsuru..."
go get github.com/tsuru/tsuru/integration

echo "Getting tsuru client..."
pushd $GOPATH/src/github.com/tsuru
git clone https://github.com/tsuru/tsuru-client.git && cd tsuru-client
if [ "$TSURUVERSION" != "latest" ]; then
  MINOR=$(echo "$TSURUVERSION" | sed -E 's/^([0-9]+\.[0-9]+).*$/\1/g')
  CLIENT_TAG=$(git tag --list "$MINOR.*" --sort=-taggerdate | head -1)
  if [ "$CLIENT_TAG" != "" ]; then
    echo "Checking out tsuru-client $CLIENT_TAG"
    git checkout $CLIENT_TAG
  fi
fi
go install ./...
popd

gcefilename=$tmpdir/google-application-credentials
echo $GCE_SERVICE_ACCOUNT > $gcefilename
export GOOGLE_APPLICATION_CREDENTIALS=$gcefilename
export TSURU_INTEGRATION_installername=$instancename
if [ -z $TSURU_INTEGRATION_clusters ]; then
  export TSURU_INTEGRATION_clusters="gce"
fi
export TSURU_INTEGRATION_examplesdir="${GOPATH}/src/github.com/tsuru/platforms/examples"
export TSURU_INTEGRATION_installerconfig=${finalconfigpath}
export TSURU_INTEGRATION_nodeopts="iaas=dockermachine"
export TSURU_INTEGRATION_maxconcurrency=4
export TSURU_INTEGRATION_enabled=1
if [ -z $TSURU_INTEGRATION_verbose ]; then
  export TSURU_INTEGRATION_verbose=1
fi

go test -v -timeout 120m github.com/tsuru/tsuru/integration

rm -f ${finalconfigpath}
