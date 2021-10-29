### ECS Cluster
resource "aws_ecs_cluster" "ecs_vpc" {
  name = "${var.prefix}-${var.mesh_name}"
}

### ECR for storing images
resource "aws_ecr_repository" "frontend" {
  name                 = "frontend"
}
resource "aws_ecr_repository" "backend" {
  name                 = "backend"
}
resource "aws_ecr_repository" "envoy" {
  name                 = "envoy"
}

### AWS App Mesh
resource "aws_appmesh_mesh" "ecs_mesh" {
  name = "${var.prefix}-${var.mesh_name}"
  spec {
    egress_filter {
      type = "DROP_ALL"
    }
  }
}

### Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.prefix}.${var.root_mesh_domain}"
  description = "all services will be registered under this common namespace"
  vpc         = aws_vpc.ecs_vpc.id
}

### AWS ACM PCA

resource "aws_acmpca_certificate_authority_certificate" "mesh_ca" {
  certificate_authority_arn = aws_acmpca_certificate_authority.mesh_ca.arn

  certificate       = aws_acmpca_certificate.mesh_ca.certificate
  certificate_chain = aws_acmpca_certificate.mesh_ca.certificate_chain
}

resource "aws_acmpca_certificate" "mesh_ca" {
  certificate_authority_arn   = aws_acmpca_certificate_authority.mesh_ca.arn
  certificate_signing_request = aws_acmpca_certificate_authority.mesh_ca.certificate_signing_request
  signing_algorithm           = "SHA512WITHRSA"

  template_arn = "arn:${data.aws_partition.current.partition}:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = 3
  }
}

resource "aws_acmpca_certificate_authority" "mesh_ca" {
  type = "ROOT"

  certificate_authority_configuration {
    key_algorithm     = "RSA_4096"
    signing_algorithm = "SHA512WITHRSA"

    subject {
      common_name = "${var.prefix}.${var.root_mesh_domain}"
    }
  }
}

data "aws_partition" "current" {}