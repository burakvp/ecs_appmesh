data "aws_iam_policy_document" "ecs_task_execution_role" {
  // version for policy
  version   = "2012-10-17"
  // state for policy to allow service to assume role
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

// ecs task execution role
resource "aws_iam_role" "ecs_task_execution_role" {
  // set name for role 
  name                = "${var.prefix}-${var.mesh_name}-task-execution-role"
  // attach policy to role 
  assume_role_policy  =  data.aws_iam_policy_document.ecs_task_execution_role.json
}

// ecs task execution role policy attachment
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role        = aws_iam_role.ecs_task_execution_role.name
  policy_arn  = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


// ecs task allow appmesh permissions policy attachment
resource "aws_iam_role_policy_attachment" "ecs_appmesh_envoy_access_role" {
  role        = aws_iam_role.ecs_task_execution_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess"
}

// ecs task allow xray permissions 
resource "aws_iam_role_policy_attachment" "ecs_xray_write_role" {
  role        = aws_iam_role.ecs_task_execution_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}