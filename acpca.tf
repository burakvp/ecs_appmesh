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