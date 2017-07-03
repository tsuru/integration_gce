#!/bin/bash

set -e

function abspath() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
mypath=$(abspath $(dirname ${BASH_SOURCE[0]}))
finalconfigpath=$(mktemp)
cp ${mypath}/config.yml ${finalconfigpath}
instancename=$(echo "integration-test-$RANDOM")
sed -i.bak "s|\$GCE_INSTANCE_NAME|${instancename}|g" ${finalconfigpath}
sed -i.bak "s|\$GCE_PROJECT_ID|${GCE_PROJECT_ID}|g" ${finalconfigpath}
sed -i.bak "s|\$GCE_ZONE|${GCE_ZONE}|g" ${finalconfigpath}

tmpdir=$(mktemp -d)
export GOPATH=${tmpdir}
export PATH=$GOPATH/bin:$PATH
echo "Go get platforms..."
go get github.com/tsuru/platforms/...
echo "Go get tsuru..."
go get github.com/tsuru/tsuru/integration
echo "Go get tsuru client..."
go get github.com/tsuru/tsuru-client/...

gcefilename=$tmpdir/google-application-credentials
echo $GCE_SERVICE_ACCOUNT > $gcefilename
export GOOGLE_APPLICATION_CREDENTIALS=$gcefilename
export TSURU_INTEGRATION_installername=$instancename
export TSURU_INTEGRATION_clusters="gce"
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
