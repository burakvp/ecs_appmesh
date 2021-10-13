resource "aws_appmesh_mesh" "ecs_mesh" {
  name = "${var.prefix}-${var.mesh_name}"
  spec {
    egress_filter {
      type = "DROP_ALL"
    }
  }
}