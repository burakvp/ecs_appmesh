resource "aws_appmesh_mesh" "ecs_mesh" {
  name = "ecs-app-mesh"
  spec {
    egress_filter {
      type = "DROP_ALL"
    }
  }
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "test.local"
  description = "all services will be registered under this common namespace"
  vpc         = aws_vpc.ecs_vpc.id
}