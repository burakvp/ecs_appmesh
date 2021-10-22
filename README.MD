# Example of mTLS on Fargate ECS with PCA
Implements mTLS based on https://awsfeed.com/whats-new/security/how-to-use-acm-private-ca-for-enabling-mtls-in-aws-app-mesh

## How to run
1) Build frontend, backend and envoy images from `src` folder and push to some Docker registry
2) update example.tfvars with your images, your public ip, public key for bastion host, and other vars if needed
4) Run `terraform apply -var-file="example.tfvars"`. Not all dependencies were correctly put, so you might need to repeat `terraform apply`.