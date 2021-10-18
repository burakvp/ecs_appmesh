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
    security_groups = ["${aws_security_group.app_gateway.id}", aws_security_group.bastion-sg.id, aws_security_group.ecs_frontend_task.id]
  }

  ingress {
    protocol        = "tcp"
    from_port       = "9901"
    to_port         = "9901"
    security_groups = ["${aws_security_group.app_gateway.id}", aws_security_group.bastion-sg.id]
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
    "image": "840364872350.dkr.ecr.us-east-1.amazonaws.com/aws-appmesh-envoy:v1.17.2.0-prod",
    "essential": true,
    "networkMode": "awsvpc",
    "memoryReservation": 256,
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