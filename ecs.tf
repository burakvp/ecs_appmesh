### ECS
resource "aws_ecs_cluster" "ecs_vpc" {
  name = "${var.prefix}-${var.mesh_name}"
}