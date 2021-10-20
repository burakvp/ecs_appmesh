import json
import boto3
import base64
import os
sm = boto3.client('secretsmanager')
cm = boto3.client('acm')
pca = boto3.client('acm-pca')

client_ca = os.environ['CLIENT_CA']
secret = os.environ['SECRET']

def lambda_handler(event, context):
    print (json.dumps(event))
    passphrase = sm.get_random_password(ExcludePunctuation=True)['RandomPassword']
    passphrase_enc = base64.b64encode(passphrase.encode('utf-8'))
    gate_rsp = cm.export_certificate(CertificateArn=client_ca, Passphrase=passphrase_enc)
    sm_value={}
    sm_value['ClientCert']=gate_rsp['Certificate']
    sm_value['ClientCertChain']=gate_rsp['CertificateChain']
    sm_value['Passphrase']=passphrase
    sm.put_secret_value(SecretId=secret, SecretString=json.dumps(sm_value))
    return