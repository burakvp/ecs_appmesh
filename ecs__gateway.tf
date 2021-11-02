### IAM for gateway task. The gateway will be run with this role

# Assume role policy
data "aws_iam_policy_document" "gateway_task_execution_role" {
  version   = "2012-10-17"
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

# Create execution roles that will be used by task
resource "aws_iam_role" "gateway_task_execution_role" {
  name                = "gateway-task-execution-role"
  assume_role_policy  =  data.aws_iam_policy_document.gateway_task_execution_role.json
}
# Attach common AmazonECSTaskExecutionRolePolicy to execution role
resource "aws_iam_role_policy_attachment" "gateway_task_execution_role" {
  role        = aws_iam_role.gateway_task_execution_role.name
  policy_arn  = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
# Attach role to access AWSAppMesh
resource "aws_iam_role_policy_attachment" "gateway_appmesh_envoy_access_role" {
  role        = aws_iam_role.gateway_task_execution_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess"
}

# Attach role to access XRAY API
resource "aws_iam_role_policy_attachment" "gateway_xray_write_role" {
  role        = aws_iam_role.gateway_task_execution_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Attach role to fetch certificates from ACM and Secret manager. Can be different attachment
resource "aws_iam_role_policy_attachment" "gateway-cert-policy" {
  role       = aws_iam_role.gateway_task_execution_role.name
  policy_arn = aws_iam_policy.gateway-get-acm-policy.arn
}

# Policies to export certs from ACM
resource "aws_iam_policy" "gateway-get-acm-policy" {
  name        = "gateway-get-acm-policy"
  description = "get-acm-policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
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

### Setup ALB that will be pointed to Gateway task
resource "aws_alb" "ecs_vpc" {
  name            = "${var.prefix}-${var.mesh_name}-gateway"
  subnets         = "${aws_subnet.public_ecs.*.id}"
  security_groups = ["${aws_security_group.lb.id}"]
}
# Create target group for ECS gateway task
resource "aws_alb_target_group" "gateway" {
  name        = "${var.prefix}-${var.mesh_name}-gateway"
  port        = var.gateway_port
  protocol    = "HTTPS"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"
  target_type = "ip"
}

# Configure ALB Listener and point it to ECS task target group
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

# Configure securiti group for ALB
resource "aws_security_group" "lb" {
  name        = "${var.prefix}-${var.mesh_name}-alb"
  description = "controls access to the ALB"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["${var.allow_ip_subnet}"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### ECS Task related configuraiton

# Configure task definitions
resource "aws_ecs_task_definition" "gateway" {
  family                   = "${var.prefix}-${var.mesh_name}-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.fargate_cpu}"
  memory                   = "${var.fargate_memory}"
  task_role_arn             = aws_iam_role.gateway_task_execution_role.arn
  execution_role_arn        = aws_iam_role.gateway_task_execution_role.arn
  container_definitions = <<DEFINITION
[
  {
    "name": "${var.prefix}-${var.mesh_name}-gateway",
    "image": "${var.envoy_image}",
    "essential": true,
    "networkMode": "awsvpc",
    "cpu": ${var.fargate_cpu},
    "memory": ${var.fargate_memory},
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

# Configure ECS Service
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

# Register ECS task to service discovery
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

# Configure security group for gateway. ALB security group needs ingress access here
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

### AWS App Mesh related configuraion 
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

# Route to frontend
resource "aws_appmesh_gateway_route" "frontend" {
  name                 = "${var.prefix}-${var.mesh_name}-frontend-route"
  mesh_name            = aws_appmesh_mesh.ecs_mesh.name
  virtual_gateway_name = aws_appmesh_virtual_gateway.gateway.name

  spec {
    http_route {
      action {
        target {
          virtual_service {
            virtual_service_name = aws_appmesh_virtual_service.frontend.name
          }
        }
      }
      match {
        prefix = "/"
      }
    }
  }
}

# Issue Gateway task certificate
resource "aws_acm_certificate" "gateway_cert" {
  domain_name       = "gateway.${var.prefix}.${var.root_mesh_domain}"
  certificate_authority_arn = aws_acmpca_certificate_authority.mesh_ca.arn

  lifecycle {
    create_before_destroy = true
  }
}

# Issue ALB Certificate
resource "aws_acm_certificate" "alb_cert" {
  domain_name       = "alb.${var.prefix}.${var.root_mesh_domain}"
  certificate_authority_arn = aws_acmpca_certificate_authority.mesh_ca.arn

  lifecycle {
    create_before_destroy = true
  }
}