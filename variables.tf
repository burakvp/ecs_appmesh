variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-east-1"
}

variable "mesh_name" {
  description = "The name of mesh"
  default     = "fargate"
}

variable "prefix" {
  description = "The AWS region to create things in."
  default     = "N760861"
}


variable "aws_account_id" {
  description = "AWS account ID"
}

variable "az_count" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "app_image" {
  description = "Docker image to run in the ECS cluster"
  default     = "adongy/hostname-docker:latest"
}

variable "ecs_gateway_image" {
  description = "Docker image to run in the ECS cluster"
  default     = "840364872350.dkr.ecr.us-east-1.amazonaws.com/aws-appmesh-envoy:v1.17.2.0-prod"
}

variable "app_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 3000
}

variable "ecs_gateway_port" {
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