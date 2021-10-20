import json
import boto3
import base64
import os
sm = boto3.client('secretsmanager')
cm = boto3.client('acm')
pca = boto3.client('acm-pca')

ca_cert_arn = os.environ['CA_CERT_ARN']
client_cert = os.environ['CLIENT_CERT_ARN']
secret = os.environ['SECRET']

def get_ca_certificate_chain(ca_arn):
    # TODO: error handling
    response = cm.get_certificate_authority_certificate(CertificateAuthorityArn=ca_arn)
    ca_chain = response['Certificate'] + response['CertificateChain']
    return ca_chain

def get_client_certificate(client_cert):
    # TODO: erro handling
    passphrase = sm.get_random_password(ExcludePunctuation=True)['RandomPassword']
    passphrase_enc = base64.b64encode(passphrase.encode('utf-8'))
    response = cm.export_certificate(CertificateArn=client_cert, Passphrase=passphrase_enc)
    return response['Certificate'], response['PrivateKey'], passphrase

def lambda_handler(event, context):
    print (json.dumps(event))
    ca_certificate_chain = get_ca_certificate_chain(ca_cert_arn)
    client_certificate, client_private_key, passphrase =  get_client_certificate(client_cert)
    sm.put_secret_value(SecretId=secret, SecretString=json.dumps({
        "CaCertificateChain": ca_certificate_chain,
        "ClientCertiticate": client_certificate,
        "ClientPrivateKey": client_private_key,
        "ClientPrivateKeyPassphrase": passphrase
    }))
    return