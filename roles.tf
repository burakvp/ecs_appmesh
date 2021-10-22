data "aws_iam_policy_document" "ecs_task_execution_role" {
  // version for policy
  version   = "2012-10-17"
  // state for policy to allow service to assume role
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

// ecs task execution role
resource "aws_iam_role" "ecs_task_execution_role" {
  // set name for role 
  name                = "${var.prefix}-${var.mesh_name}-task-execution-role"
  // attach policy to role 
  assume_role_policy  =  data.aws_iam_policy_document.ecs_task_execution_role.json
}

// ecs task execution role policy attachment
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role        = aws_iam_role.ecs_task_execution_role.name
  policy_arn  = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


// ecs task allow appmesh permissions policy attachment
resource "aws_iam_role_policy_attachment" "ecs_appmesh_envoy_access_role" {
  role        = aws_iam_role.ecs_task_execution_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess"
}

// ecs task allow xray permissions 
resource "aws_iam_role_policy_attachment" "ecs_xray_write_role" {
  role        = aws_iam_role.ecs_task_execution_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy_attachment" "cert-policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.get-acm-policy.arn
}

#TODO figure out how to manage acces to certs in more convinient and relieable way
resource "aws_iam_policy" "get-acm-policy" {
  name        = "get-acm-policy"
  description = "get-acm-policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "acm:ExportCertificate",
            "Resource": "${aws_acm_certificate.frontend_cert.arn}"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "acm:ExportCertificate",
            "Resource": "${aws_acm_certificate.backend_cert.arn}"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "acm:ExportCertificate",
            "Resource": "${aws_acm_certificate.gateway_cert.arn}"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "acm-pca:GetCertificateAuthorityCertificate",
            "Resource": "${aws_acmpca_certificate_authority.mesh_ca.arn}"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "*" 
        }
    ]
}
EOF
}