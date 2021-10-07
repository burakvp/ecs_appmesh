resource "aws_service_discovery_service" "envoy_proxy" {
  name = "test-virtual-gateway.local"

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

resource "aws_appmesh_virtual_gateway" "vgateway" {
  name      = "test-vg"
  mesh_name = aws_appmesh_mesh.main.name

  spec {
    listener {
      port_mapping {
        port     = 80
        protocol = "http"
      }

      health_check {
        port                = 80
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

resource "aws_appmesh_gateway_route" "route" {
  name                 = "test-gateway-route"
  virtual_gateway_name = aws_appmesh_virtual_gateway.vgateway.name
  mesh_name            = aws_appmesh_mesh.main.name
  spec {
    http_route {
      action {
        target {
          virtual_service {
            virtual_service_name = aws_appmesh_virtual_service.app.name
          }
        }
      }

      match {
        prefix = "/"
      }
    }
  }
}


// add envoy proxy 
module "envoy-proxy" {
  source            = "./../ecs-fargate"
  region            = "us-east-1"
  app_name          = "test"
  app_port          = "80"
  env               = "dev"
  vpc               = module.vpc
  cloudmap_service  = aws_service_discovery_service.envoy_proxy
  appmesh           = aws_appmesh_mesh.main
  virtual_gateway   = "test-vg"
}