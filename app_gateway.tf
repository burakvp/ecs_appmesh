## NETWORK
# Setup ALB for gatewas
resource "aws_alb" "ecs_vpc" {
  name            = "${var.prefix}-${var.mesh_name}-app-gateway"
  subnets         = "${aws_subnet.public_ecs.*.id}"
  security_groups = ["${aws_security_group.lb.id}"]
}

resource "aws_alb_target_group" "app_gateway" {
  name        = "${var.prefix}-${var.mesh_name}-app-gateway"
  port        = var.app_gateway_port
  protocol    = "HTTPS"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"
  target_type = "ip"
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "app_gateway" {
  load_balancer_arn = "${aws_alb.ecs_vpc.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.app_gateway.id}"
    type             = "forward"
  }
}
resource "aws_security_group" "lb" {
  name        = "${var.prefix}-${var.mesh_name}-alb"
  description = "controls access to the ALB"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
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
resource "aws_ecs_task_definition" "app_gateway" {
  family                   = "${var.prefix}-${var.mesh_name}-app_gateway"
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
    "name": "${var.prefix}-${var.mesh_name}-app_gateway",
    "image": "840364872350.dkr.ecr.us-east-1.amazonaws.com/aws-appmesh-envoy:v1.17.2.0-prod",
    "essential": true,
    "networkMode": "awsvpc",
    "cpu": ${var.fargate_cpu},
    "memory": ${var.fargate_memory},
    "environment": [
      {
        "name": "APPMESH_VIRTUAL_NODE_NAME",
        "value": "mesh/${var.prefix}-${var.mesh_name}/virtualGateway/${var.prefix}-${var.mesh_name}-app_gateway"
      },
      {
        "name": "ENABLE_ENVOY_XRAY_TRACING",
        "value": "1"
      }
      ],
    "portMappings": [
      {
        "hostPort": ${var.app_gateway_port},
        "containerPort": ${var.app_gateway_port}
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

resource "aws_ecs_service" "app_gateway" {
  name            = "${var.prefix}-${var.mesh_name}-app_gateway"
  cluster         = aws_ecs_cluster.ecs_vpc.id
  task_definition = aws_ecs_task_definition.app_gateway.arn
  desired_count   = "${var.app_count}"
  launch_type     = "FARGATE"
  
  service_registries {
    registry_arn = aws_service_discovery_service.app_gateway.arn
  }

  network_configuration {
    security_groups = ["${aws_security_group.app_gateway.id}", aws_security_group.bastion-sg.id]
    subnets         = "${aws_subnet.private_ecs.*.id}"
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.app_gateway.id}"
    container_name   = "${var.prefix}-${var.mesh_name}-app_gateway"
    container_port   = "${var.app_gateway_port}"
  }

  depends_on = [
    aws_alb_listener.app_gateway,
    aws_ecs_task_definition.app_gateway
  ]
}

resource "aws_security_group" "app_gateway" {
  name        = "${var.prefix}-${var.mesh_name}-app-gateway"
  description = "allow inbound access from the ALB only"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"

  ingress {
    protocol        = "tcp"
    from_port       = "${var.app_gateway_port}"
    to_port         = "${var.app_gateway_port}"
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

resource "aws_appmesh_virtual_gateway" "app_gateway" {
  name      = "${var.prefix}-${var.mesh_name}-app_gateway"
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
        port     = var.app_gateway_port
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
        port                = var.app_gateway_port
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

resource "aws_service_discovery_service" "app_gateway" {
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