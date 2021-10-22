resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.prefix}.${var.root_mesh_domain}"
  description = "all services will be registered under this common namespace"
  vpc         = aws_vpc.ecs_vpc.id
}