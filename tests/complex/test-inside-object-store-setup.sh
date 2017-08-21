#!/bin/bash

# test object store setup

S3_CURL_URL="${1}"
shift
S3_ACCOUNT="${1:-account}"
shift
S3_USER="${1:-user}"
shift
S3_PASSWORD="${1:-password}"
shift

if [ ! -f s3-curl/s3curl.pl ]; then
  wget -O s3-curl.zip "${S3_CURL_URL}"
  unzip s3-curl.zip
fi

sudo chmod -R a+rw s3-curl
sudo chmod a+x s3-curl/s3curl.pl

cat >~/.s3curl <<END
%awsSecretAccessKeys = (
    '${S3_ACCOUNT}:${S3_USER}' => {
        id => '${S3_ACCOUNT}:${S3_USER}',
        key => '${S3_PASSWORD}',
    },
);
END

chmod 600 ~/.s3curl

cd s3-curl || exit 1

S3_IP=$(kubectl get svc/gluster-s3-service --template '{{.spec.clusterIP}}')


python - <<END
# conding: utf8
import re

with open("s3curl.pl", "r") as f:
    file_contents = f.read()

new_contents = re.sub("my @endpoints = \( [^)]* \);", "my @endpoints = ( '${S3_IP}', );", file_contents, flags=re.M)

with open("s3curl.pl", "w") as f:
    f.write( new_contents )
END

exit 0
