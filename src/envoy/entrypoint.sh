#!/bin/bash

# set -xe

PASSPHRASE=`echo $CertSecret|jq -r '.ClientPrivateKeyPassphrase'`
PASSPHRASE_B64=`echo -n $PASSPHRASE | base64`


# -------- CollorGateway Cert ----------
echo $CertSecret|jq -r '.CaCertificateChain' | base64 -d > /keys/ca_cert.pem
echo $CertSecret|jq -r '.ClientCertificate' | base64 -d > /keys/client_cert.pem
echo $CertSecret|jq -r '.ClientPrivateKey' | base64 -d > /keys/client_cert_key_enc.pem

# cat /keys/client_cert_key_enc.pem
cat /keys/client_cert.pem
# cat /keys/ca_cert.pem
openssl rsa -in /keys/client_cert_key_enc.pem -out /keys/client_cert_key.pem -passin pass:$PASSPHRASE_B64
openssl rsa -in /keys/client_cert_key.pem -check

# Clear environment of secret values
unset CertSecret
unset PASSPHRASE
unset PASSPHRASE_B64

# Start Envoy
/usr/bin/envoy-wrapper