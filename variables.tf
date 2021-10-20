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
  default     = "514072627411.dkr.ecr.us-east-1.amazonaws.com/frontend:0.0.1"
}

variable "backend_image" {
  description = "Docker image to run in the ECS cluster"
  default     = "514072627411.dkr.ecr.us-east-1.amazonaws.com/backend:0.0.1"
}
variable "envoy_image" {
  description = "Docker image to run in the ECS cluster"
  default     = "514072627411.dkr.ecr.us-east-1.amazonaws.com/envoy:0.0.1"
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
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNHqHEhyJVy5vlPacO1QqOdVNXJB/jSYHoSykLeK/8NvfGc7SdPi4WmvbCrBL/12qSvhVi7/8VYgclVM1QfqZ3OBLShTJSAVr5pn67Z1KrG5GALlS0qJadEmqVzjjxy9sy//WS2xAw0yxiwWjRjj0KMlAb3SBqxqeTIJVGd5DVlC091zyRCJq3G4xYGpHOPF7t3mWTJyW0jCeFQqO3fux6cqGjNG9hE3WcHDzxGjG2JofVwTjAZC/rjPRYGHF1Cg0MaJXUyJhbbMKiUooN8xxmDt5qRGKq0CzM3nuxsP3H8bV6St/DwQQTchs8Vz5XWOjHPibOjTWIQsZcfycbtckO/R3fMg7RsEzHm1dVSgqg/tDRNDJG+sFZQcM+BAf19xL5Ea3HIt5NbdQ+okTkv2fZJBRrreJh7iDf8R6Uu6whX7PRGdZ/77/qVSzrYM8Mek/UiEZ1Yn2pJrszIuBOiF7VuqcbhRP4juc7EW3KlOR3+AJXUVWSGUbyP+8Q26LWaxkkucyPGxF8u2nEQ8+tkQBpIqFXpDowCoFVR3+OFwUTnKF4IiJYB2dExwHAyfesy5BFFcyLTOYs/LdpCenqneP5ONDmlksAqLilDse2oOv7hmhjgUeqmoOA+Ukygr7R9DrU23CVxjtjIhUzeoAf3ya0KUt9mxhBd5kXOf/UllEAyQ== vitalii.burak@jmpchase.com"
}

variable "root_mesh_domain" {
  description = "Top level domain of private DNS"
  default = "ecs-mesh"
}