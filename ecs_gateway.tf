## NETWORK
# Setup ALB for gatewas
resource "aws_alb" "ecs_vpc" {
  name            = "${var.prefix}-${var.mesh_name}-ecs-gateway"
  subnets         = "${aws_subnet.public_ecs.*.id}"
  security_groups = ["${aws_security_group.lb.id}"]
}

resource "aws_alb_target_group" "ecs_gateway" {
  name        = "${var.prefix}-${var.mesh_name}-ecs-gateway"
  port        = var.ecs_gateway_port
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"
  target_type = "ip"
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "ecs_gateway" {
  load_balancer_arn = "${aws_alb.ecs_vpc.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.ecs_gateway.id}"
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
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_ecs_task_definition" "ecs_gateway" {
  family                   = "${var.prefix}-${var.mesh_name}-ecs_gateway"
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
    "name": "${var.prefix}-${var.mesh_name}-ecs_gateway",
    "image": "840364872350.dkr.ecr.us-east-1.amazonaws.com/aws-appmesh-envoy:v1.17.2.0-prod",
    "essential": true,
    "networkMode": "awsvpc",
    "cpu": ${var.fargate_cpu},
    "memory": ${var.fargate_memory},
    "environment": [
      {
        "name": "APPMESH_VIRTUAL_NODE_NAME",
        "value": "mesh/${var.prefix}-${var.mesh_name}/virtualGateway/${var.prefix}-${var.mesh_name}-ecs_gateway"
      }
      ],
    "portMappings": [
      {
        "hostPort": ${var.ecs_gateway_port},
        "containerPort": ${var.ecs_gateway_port}
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
  }
]
DEFINITION
}

resource "aws_ecs_service" "ecs_gateway" {
  name            = "${var.prefix}-${var.mesh_name}-ecs_gateway"
  cluster         = aws_ecs_cluster.ecs_vpc.id
  task_definition = aws_ecs_task_definition.ecs_gateway.arn
  desired_count   = "${var.app_count}"
  launch_type     = "FARGATE"
  
  service_registries {
    registry_arn = aws_service_discovery_service.ecs_gateway.arn
  }

  network_configuration {
    security_groups = ["${aws_security_group.ecs_gateway.id}", aws_security_group.bastion-sg.id]
    subnets         = "${aws_subnet.private_ecs.*.id}"
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.ecs_gateway.id}"
    container_name   = "${var.prefix}-${var.mesh_name}-ecs_gateway"
    container_port   = "${var.ecs_gateway_port}"
  }

  depends_on = [
    aws_alb_listener.ecs_gateway,
    aws_ecs_task_definition.ecs_gateway
  ]
}

resource "aws_security_group" "ecs_gateway" {
  name        = "${var.prefix}-${var.mesh_name}-ecs-gateway"
  description = "allow inbound access from the ALB only"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"

  ingress {
    protocol        = "tcp"
    from_port       = "${var.ecs_gateway_port}"
    to_port         = "${var.ecs_gateway_port}"
    security_groups = ["${aws_security_group.lb.id}"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_appmesh_virtual_gateway" "ecs_gateway" {
  name      = "${var.prefix}-${var.mesh_name}-ecs_gateway"
  mesh_name = aws_appmesh_mesh.ecs_mesh.name

  spec {
    logging {
      access_log {
        file {
          path = "/dev/stdout"
        }
      }
    }
    listener {
      port_mapping {
        port     = var.ecs_gateway_port
        protocol = "http"
      }

      health_check {
        port                = var.ecs_gateway_port
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

resource "aws_service_discovery_service" "ecs_gateway" {
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