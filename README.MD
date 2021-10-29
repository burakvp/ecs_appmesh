# Example of mTLS on Fargate ECS with PCA
Implements mTLS based on https://awsfeed.com/whats-new/security/how-to-use-acm-private-ca-for-enabling-mtls-in-aws-app-mesh

## How to run
1) Build frontend, backend and envoy images from `src` folder and push to some Docker registry
2) update example.tfvars with your images, your public ip, public key for bastion host, and other vars if needed
4) Run `terraform apply -var-file="example.tfvars"`. Not all dependencies were correctly put, so you might need to repeat `terraform apply`.

# TODO
- Sort Task and labmda execution permissions


# Terraform Modules Structure

## Main ECS cluster Module

Main module that is supposed configure all needed infrastructure and make it ready to host client applications.

### Configures

- acmp_ca - Creates PCA and CA certificates, mb we can pass it as input and create as separate module
- aws_ecr_repository - Creates ECR repositories for common images like envoy proxy, sidecars, etc
- aws_ecs_cluster - ECS cluster itself
- aws_appmesh_mesh - App mesh instance and its default configuration
- aws_service_discovery_private_dns_namespace - Route53 private dns namespace
- ecs-cluster-roles(?) - Default clusterwide roles
---
- ?app_mesh_gateway and alb? - Decide if this needs to be here or in seprarate modeues

### Inputs
- mesh-name
- dns-private-zone
- CA related inputs?
- ECS cluster roles

### Outputs
- esh-name
- ecs-cluster-name
- dns-private-zone
- CA authority ARN

## ECS App Mesh Gateway (needs additional consideration)
Configuration of App Mesh gateway that will be entry point for all incomming traffic. It can be either bare ALB or App Mesh Gateway

# Configures
- ALB
- Security Groups for ingress
- DNS name
- Certificate
- labmda for placing cert in secretmanager
- (in case of APP Mesh Gateway)
    - Task for virtual gateway
    - App mesh specific configuraiotns for virtual-gateway
    - Routes to upstream services


## ECS Application module

Application module that is suppose to describe deployable client application in ECS.

### Configures Resources

- task execution role - Configures task level previleges
- aws_security_group - Configures access contol based on dependencies
- aws_ecs_task_definition - Configures task definitions
- aws_ecs_service - Configures ECS Service definitions
- aws_service_discovery_service - Configures Service to be ready fo service discovery
- aws_acm_certificate - Issues ACM end certificate for service
- labmda for placing cert in secretmanager
- app-mesh-specifics entities (might be passed as inputs and configured separately)
    - aws_appmesh_virtual_node
    - aws_appmesh_virtual_service
    - aws_appmesh_virtual_router
    - aws_appmesh_router

### Inputs
- Application Name
- App container specific configurations
    - image
    - resources
    - environment variables
    - secrets
    - etc
- service dependencies - to configure security_groups, App-mesh
- pluggable extentions
    - datadog