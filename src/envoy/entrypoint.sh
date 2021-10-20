#!/bin/bash

set -xe

PASSPHRASE=`echo $CertSecret|jq -r '.Passphrase'`


# -------- CollorGateway Cert ----------
echo $CertSecret|jq -r '.ClientCert' > /keys/client_cert.pem
echo $CertSecret|jq -r '.ClientCertChain' > /keys/client_cert_ca.pem

cat /keys/client_cert.pem /keys/client_cert_ca.pem > /keys/client_cert_chain.pem

# Clear environment of secret values
unset CertSecret
unset PASSPHRASE
unset PASSPHRASE_B64

# Start Envoy
/usr/bin/envoy-wrapper