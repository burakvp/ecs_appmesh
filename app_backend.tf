# Traffic to the ECS Cluster should only come from the ALB
locals {
  backend_name = "backend"
}
resource "aws_security_group" "ecs_backend_task" {
  name        = "${var.prefix}-${var.mesh_name}-${local.backend_name}"
  description = "Allow from application gateway"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"

  ingress {
    protocol        = "tcp"
    from_port       = "${var.app_port}"
    to_port         = "${var.app_port}"
    security_groups = [aws_security_group.bastion-sg.id, aws_security_group.ecs_frontend_task.id]
  }

  ingress {
    protocol        = "tcp"
    from_port       = "9901"
    to_port         = "9901"
    security_groups = [aws_security_group.bastion-sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.prefix}-${var.mesh_name}-${local.backend_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.fargate_cpu}"
  memory                   = "${var.fargate_memory}"
  task_role_arn             = aws_iam_role.ecs_task_execution_role.arn
  // attach a role to definition described in role.tf
  execution_role_arn        = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = <<DEFINITION
[
  {
    "cpu": ${var.fargate_cpu},
    "image": "${var.backend_image}",
    "memory": ${var.fargate_memory},
    "name": "${var.prefix}-${var.mesh_name}-${local.backend_name}",
    "networkMode": "awsvpc",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/${var.prefix}",
        "awslogs-region": "${var.aws_region}",
        "awslogs-stream-prefix": "${local.backend_name}${var.prefix}"
      }
    },
    "portMappings": [
      {
        "containerPort": ${var.app_port},
        "hostPort": ${var.app_port}
      }
    ]
  },
  {
    "name": "${var.prefix}-${var.mesh_name}-${local.backend_name}-proxy",
    "image": "${var.envoy_image}",
    "essential": true,
    "networkMode": "awsvpc",
    "memoryReservation": 256,
    "secrets": [
      {
        "name": "CertSecret",
        "valueFrom": "${aws_secretsmanager_secret.backend_cert.arn}"
      }
    ],
    "environment": [
      {
        "name": "APPMESH_VIRTUAL_NODE_NAME",
        "value": "mesh/${var.prefix}-${var.mesh_name}/virtualNode/${var.prefix}-${var.mesh_name}-${local.backend_name}"
      },
      {
        "name": "ENABLE_ENVOY_XRAY_TRACING",
        "value": "1"
      }
    ],  
    "portMappings": [
        {
          "hostPort": 9901,
          "protocol": "tcp",
          "containerPort": 9901
        }
    ],
    "healthCheck": {
      "command": [
        "CMD-SHELL",
        "curl -s http://localhost:9901/server_info | grep state | grep -q LIVE"
      ],
      "startPeriod": 10,
      "interval": 5,
      "timeout": 2,
      "retries": 3
    },
    "user": "1337",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/${var.prefix}",
        "awslogs-region": "${var.aws_region}",
        "awslogs-stream-prefix": "envoy${var.prefix}"
      }
    },
    "ulimits": [
      {
        "softLimit": 15000,
        "hardLimit": 15000,
        "name": "nofile"
      }
    ]
  },
  {
    "name": "xray-daemon",
    "image": "amazon/aws-xray-daemon",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/${var.prefix}",
        "awslogs-region": "${var.aws_region}",
        "awslogs-stream-prefix": "xray${var.prefix}"
      }
    },
    "portMappings" : [
        {
            "hostPort": 2000,
            "containerPort": 2000,
            "protocol": "udp"
        }
    ]
  }
]
DEFINITION
  proxy_configuration {
    type           = "APPMESH"
    container_name = "${var.prefix}-${var.mesh_name}-${local.backend_name}-proxy"
    properties = {
      AppPorts         = "${var.app_port}"
      EgressIgnoredIPs = "169.254.170.2,169.254.169.254"
      IgnoredUID       = "1337"
      ProxyEgressPort  = 15001
      ProxyIngressPort = 15000
    }
  }
}

resource "aws_ecs_service" "backend" {
  name            = "${var.prefix}-${var.mesh_name}-${local.backend_name}"
  cluster         = "${aws_ecs_cluster.ecs_vpc.id}"
  task_definition = "${aws_ecs_task_definition.backend.arn}"
  desired_count   = "${var.app_count}"
  launch_type     = "FARGATE"
  service_registries {
    registry_arn = aws_service_discovery_service.backend.arn
  }
  network_configuration {
    security_groups = ["${aws_security_group.ecs_backend_task.id}"]
    subnets         = "${aws_subnet.private_ecs.*.id}"
  }
}

resource "aws_appmesh_virtual_node" "backend" {
  name      = "${var.prefix}-${var.mesh_name}-${local.backend_name}"
  mesh_name = aws_appmesh_mesh.ecs_mesh.name

  spec {
    listener {
      port_mapping {
        port     = var.app_port
        protocol = "http"
      }
      tls {
        mode = "STRICT"
        validation {
          trust {
            file {
              certificate_chain = "/keys/ca_cert.pem" #For client verification
            }
          }
        }
        certificate {
          acm {
            certificate_arn = aws_acm_certificate.backend_cert.arn # Server cert configuration
          }
        } 
      }
    }
    logging {
      access_log {
        file {
          path = "/dev/stdout"
        }
      }
    }
    service_discovery {
      aws_cloud_map {
        namespace_name =  aws_service_discovery_private_dns_namespace.main.name
        service_name = aws_service_discovery_service.backend.name
      }
    }
  }
}
resource "aws_appmesh_virtual_service" "backend" {
  name      = "${local.backend_name}.${var.prefix}.${var.root_mesh_domain}"
  mesh_name = aws_appmesh_mesh.ecs_mesh.name

  spec {
    provider {
      virtual_node {
        virtual_node_name = aws_appmesh_virtual_node.backend.name
      }
    }
  }
}
resource "aws_service_discovery_service" "backend" {
  name = "${local.backend_name}"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_acm_certificate" "backend_cert" {
  domain_name       = "${local.backend_name}.${var.prefix}.${var.root_mesh_domain}"
  certificate_authority_arn = aws_acmpca_certificate_authority.mesh_ca.arn

  lifecycle {
    create_before_destroy = true
  }
}


### Labmda to get certificates

resource "aws_secretsmanager_secret" "backend_cert" {
  name = "backend_cert"
}

resource "aws_iam_role" "iam_for_lambda_backend" {
  name = "iam_for_lambda_backend"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "fetch-backend-cert" {
  role       = aws_iam_role.iam_for_lambda_backend.name
  policy_arn = aws_iam_policy.fetch-backend-cert.arn
}

#TODO figure out how to manage acces to certs in more convinient and relieable way
resource "aws_iam_policy" "fetch-backend-cert" {
  name        = "fetch-backend-cert"
  description = "fetch-backend-cert"
  # TODO FIX PERMISSIONS RESOURCE *
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "secretsmanager:GetRandomPassword",
            "Resource": "*"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "secretsmanager:PutSecretValue",
            "Resource": "*" 
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
            "Action": "acm-pca:GetCertificateAuthorityCertificate",
            "Resource": "${aws_acmpca_certificate_authority.mesh_ca.arn}"
        }
    ]
}
EOF
}

data "archive_file" "backend_cert_lambda_zip" {
    type          = "zip"
    source_file   = "lambda.py"
    output_path   = "lambda.zip"
}


resource "aws_lambda_function" "backend_cert_lambda" {
  filename      = "lambda.zip"
  function_name = "backend_lambda_handler"
  role          = aws_iam_role.iam_for_lambda_backend.arn
  handler       = "lambda.lambda_handler"

  source_code_hash = data.archive_file.backend_cert_lambda_zip.output_base64sha256

  runtime = "python3.8"

  environment {
    variables = {
        CLIENT_CERT_ARN = aws_acm_certificate.backend_cert.arn
        CA_CERT_ARN = aws_acmpca_certificate_authority.mesh_ca.arn
        SECRET = aws_secretsmanager_secret.backend_cert.arn
    }
  }
}

# trigger after cert created
data "aws_lambda_invocation" "backend_cert_lambda" {
  function_name = aws_lambda_function.backend_cert_lambda.function_name
  input = <<JSON
{}
JSON
  depends_on = [
    aws_acm_certificate.backend_cert,
    aws_acmpca_certificate_authority.mesh_ca
  ]
}