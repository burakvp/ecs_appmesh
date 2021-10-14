variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-east-1"
}

variable "mesh_name" {
  description = "The name of mesh"
  default     = "poc"
}

variable "prefix" {
  description = "The AWS region to create things in."
  default     = "vb"
}


variable "aws_account_id" {
  description = "AWS account ID"
  default = ""
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "frontend_image" {
  description = "Docker image to run in the ECS cluster"
  default     = ""
}

variable "backend_image" {
  description = "Docker image to run in the ECS cluster"
  default     = ""
}


variable "ecs_gateway_image" {
  description = "Docker image to run in the ECS cluster"
  default     = "840364872350.dkr.ecr.us-east-1.amazonaws.com/aws-appmesh-envoy:v1.17.2.0-prod"
}

variable "app_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 3000
}

variable "app_gateway_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 8080
}

variable "app_count" {
  description = "Number of docker containers to run"
  default     = 2
}

variable "fargate_cpu" {
  description = "Fargate instance CPU units to provision (1 vCPU = 1024 CPU units)"
  default     = "256"
}

variable "fargate_memory" {
  description = "Fargate instance memory to provision (in MiB)"
  default     = "512"
}

variable "bastion_pubkey" {
  description = "Fargate instance memory to provision (in MiB)"
  default     = ""
}