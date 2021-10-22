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
variable "envoy_image" {
  description = "Docker image to run in the ECS cluster"
  default     = ""
}

variable "allow_ip_subnet" {
  description = "Allow ip subnet"
  default     = "0.0.0.0/0"
}
variable "app_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 3000
}

variable "gateway_port" {
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

variable "root_mesh_domain" {
  description = "Top level domain of private DNS"
  default = "ecs-mesh"
}