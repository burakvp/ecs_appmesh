## NETWORK
# Setup ALB for gatewas
resource "aws_alb" "ecs_vpc" {
  name            = "${var.prefix}-${var.mesh_name}-gateway"
  subnets         = "${aws_subnet.public_ecs.*.id}"
  security_groups = ["${aws_security_group.lb.id}"]
}

resource "aws_alb_target_group" "gateway" {
  name        = "${var.prefix}-${var.mesh_name}-gateway"
  port        = var.gateway_port
  protocol    = "HTTPS"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"
  target_type = "ip"
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "gateway" {
  load_balancer_arn = "${aws_alb.ecs_vpc.id}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.alb_cert.arn

  default_action {
    target_group_arn = "${aws_alb_target_group.gateway.id}"
    type             = "forward"
  }
}
resource "aws_security_group" "lb" {
  name        = "${var.prefix}-${var.mesh_name}-alb"
  description = "controls access to the ALB"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["69.181.181.129/32"]
    ipv6_cidr_blocks = ["2607:fb90:9eb8:9ba4:f06d:2670:16e9:8b03/128"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
resource "aws_ecs_task_definition" "gateway" {
  family                   = "${var.prefix}-${var.mesh_name}-gateway"
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
    "name": "${var.prefix}-${var.mesh_name}-gateway",
    "image": "${var.envoy_image}",
    "essential": true,
    "networkMode": "awsvpc",
    "cpu": ${var.fargate_cpu},
    "memory": ${var.fargate_memory},
    "secrets": [
      {
        "name": "CertSecret",
        "valueFrom": "${aws_secretsmanager_secret.gateway_cert.arn}"
      }
    ],
    "environment": [
      {
        "name": "APPMESH_VIRTUAL_NODE_NAME",
        "value": "mesh/${var.prefix}-${var.mesh_name}/virtualGateway/${var.prefix}-${var.mesh_name}-gateway"
      },
      {
        "name": "ENABLE_ENVOY_XRAY_TRACING",
        "value": "1"
      }
      ],
    "portMappings": [
      {
        "hostPort": ${var.gateway_port},
        "containerPort": ${var.gateway_port}
      },
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
}

resource "aws_ecs_service" "gateway" {
  name            = "${var.prefix}-${var.mesh_name}-gateway"
  cluster         = aws_ecs_cluster.ecs_vpc.id
  task_definition = aws_ecs_task_definition.gateway.arn
  desired_count   = "${var.app_count}"
  launch_type     = "FARGATE"
  
  service_registries {
    registry_arn = aws_service_discovery_service.gateway.arn
  }

  network_configuration {
    security_groups = ["${aws_security_group.gateway.id}", aws_security_group.bastion-sg.id]
    subnets         = "${aws_subnet.private_ecs.*.id}"
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.gateway.id}"
    container_name   = "${var.prefix}-${var.mesh_name}-gateway"
    container_port   = "${var.gateway_port}"
  }

  depends_on = [
    aws_alb_listener.gateway,
    aws_ecs_task_definition.gateway
  ]
}

resource "aws_security_group" "gateway" {
  name        = "${var.prefix}-${var.mesh_name}-gateway"
  description = "allow inbound access from the ALB only"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"

  ingress {
    protocol        = "tcp"
    from_port       = "${var.gateway_port}"
    to_port         = "${var.gateway_port}"
    security_groups = ["${aws_security_group.lb.id}", aws_security_group.bastion-sg.id]
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

resource "aws_appmesh_virtual_gateway" "gateway" {
  name      = "${var.prefix}-${var.mesh_name}-gateway"
  mesh_name = aws_appmesh_mesh.ecs_mesh.name

  spec {
    logging {
      access_log {
        file {
          path = "/dev/stdout"
        }
      }
    }
    backend_defaults {
      client_policy {
        tls {
          certificate {
            file {
              certificate_chain = "/keys/client_cert.pem"
              private_key = "/keys/client_cert_key.pem"
            }
          }
          validation {
            subject_alternative_names {
              match {
                exact = [aws_appmesh_virtual_service.frontend.name]
              }
            }
            trust {
              acm {
                certificate_authority_arns = [aws_acmpca_certificate_authority.mesh_ca.arn]
              }
            }
          }
        }
      }
    }
    listener {
      port_mapping {
        port     = var.gateway_port
        protocol = "http"
      }
      tls {
        certificate {
          acm {
            certificate_arn = aws_acm_certificate.gateway_cert.arn
          }
        }
        mode = "STRICT"
      }
      health_check {
        port                = var.gateway_port
        protocol            = "http"
        path                = "/"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout_millis      = 2000
        interval_millis     = 5000
      }

    }
  }
}

resource "aws_service_discovery_service" "gateway" {
  name = "gateway"

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


# Certificate

resource "aws_acm_certificate" "gateway_cert" {
  domain_name       = "gateway.${var.prefix}.${var.root_mesh_domain}"
  certificate_authority_arn = aws_acmpca_certificate_authority.mesh_ca.arn

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "alb_cert" {
  domain_name       = "alb.${var.prefix}.${var.root_mesh_domain}"
  certificate_authority_arn = aws_acmpca_certificate_authority.mesh_ca.arn

  lifecycle {
    create_before_destroy = true
  }
}


### Labmda to get certificates

resource "aws_secretsmanager_secret" "gateway_cert" {
  name = "gateway_cert"
}

resource "aws_iam_role" "iam_for_lambda_gateway" {
  name = "iam_for_lambda_gateway"

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

resource "aws_iam_role_policy_attachment" "fetch-gateway-cert" {
  role       = aws_iam_role.iam_for_lambda_gateway.name
  policy_arn = aws_iam_policy.fetch-gateway-cert.arn
}

#TODO figure out how to manage acces to certs in more convinient and relieable way
resource "aws_iam_policy" "fetch-gateway-cert" {
  name        = "fetch-gateway-cert"
  description = "fetch-gateway-cert"
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
            "Resource": "${aws_acm_certificate.gateway_cert.arn}"
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

data "archive_file" "gateway_cert_lambda_zip" {
    type          = "zip"
    source_file   = "lambda.py"
    output_path   = "lambda.zip"
}


resource "aws_lambda_function" "gateway_cert_lambda" {
  filename      = "lambda.zip"
  function_name = "gateway_lambda_handler"
  role          = aws_iam_role.iam_for_lambda_gateway.arn
  handler       = "lambda.lambda_handler"

  source_code_hash = data.archive_file.gateway_cert_lambda_zip.output_base64sha256

  runtime = "python3.8"

  environment {
    variables = {
        CLIENT_CERT_ARN = aws_acm_certificate.gateway_cert.arn
        CA_CERT_ARN = aws_acmpca_certificate_authority.mesh_ca.arn
        SECRET = aws_secretsmanager_secret.gateway_cert.arn
    }
  }
}

# # trigger after cert created
data "aws_lambda_invocation" "gatewat_cert_lambda" {
  function_name = aws_lambda_function.gateway_cert_lambda.function_name
  input = <<JSON
{}
JSON
  depends_on = [
    aws_acm_certificate.gateway_cert,
    aws_acmpca_certificate_authority.mesh_ca
  ]
}