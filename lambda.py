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
    response = pca.get_certificate_authority_certificate(CertificateAuthorityArn=ca_arn)
    ca_chain = response['Certificate'] + '\n' + response.get('CertificateChain', '')
    return ca_chain

def get_client_certificate(client_cert):
    # TODO: erro handling

    # TODO: gen password in code instead of getting it from SM?
    passphrase = sm.get_random_password(ExcludePunctuation=True)['RandomPassword']
    passphrase_enc = base64.b64encode(passphrase.encode('utf-8'))
    response = cm.export_certificate(CertificateArn=client_cert, Passphrase=passphrase_enc)
    certificate_chain = response['Certificate'] + response.get('CertificateChain', '')
    return certificate_chain, response['PrivateKey'], passphrase

def lambda_handler(event, context):
    print (json.dumps(event))
    ca_certificate_chain = get_ca_certificate_chain(ca_cert_arn)
    client_certificate, client_private_key, passphrase =  get_client_certificate(client_cert)
    sm.put_secret_value(SecretId=secret, SecretString=json.dumps({
        "CaCertificateChain": base64.b64encode(ca_certificate_chain.encode('utf-8')).decode("utf-8"),
        "ClientCertificate": base64.b64encode(client_certificate.encode('utf-8')).decode("utf-8"),
        "ClientPrivateKey": base64.b64encode(client_private_key.encode('utf-8')).decode("utf-8"),
        "ClientPrivateKeyPassphrase": passphrase
    }))
    return