### Network

# Fetch AZs in the current region
data "aws_availability_zones" "available" {}

resource "aws_vpc" "ecs_vpc" {
  cidr_block = "172.17.0.0/16"
}

# Create var.az_count private_ecs subnets, each in a different AZ
resource "aws_subnet" "private_ecs" {
  count             = "${var.az_count}"
  cidr_block        = "${cidrsubnet(aws_vpc.ecs_vpc.cidr_block, 8, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.ecs_vpc.id}"
}

# Create var.az_count public_ecs subnets, each in a different AZ
resource "aws_subnet" "public_ecs" {
  count                   = "${var.az_count}"
  cidr_block              = "${cidrsubnet(aws_vpc.ecs_vpc.cidr_block, 8, var.az_count + count.index)}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id                  = "${aws_vpc.ecs_vpc.id}"
  map_public_ip_on_launch = true
}

# IGW for the public_ecs subnet
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.ecs_vpc.id}"
}

# Route the public_ecs subnet traffic through the IGW
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.ecs_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

# Create a NAT gateway with an EIP for each private_ecs subnet to get internet connectivity
resource "aws_eip" "gw" {
  count      = "${var.az_count}"
  vpc        = true
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "gw" {
  count         = "${var.az_count}"
  subnet_id     = "${element(aws_subnet.public_ecs.*.id, count.index)}"
  allocation_id = "${element(aws_eip.gw.*.id, count.index)}"
}

# Create a new route table for the private_ecs subnets
# And make it route non-local traffic through the NAT gateway to the internet
resource "aws_route_table" "private_ecs" {
  count  = "${var.az_count}"
  vpc_id = "${aws_vpc.ecs_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.gw.*.id, count.index)}"
  }
}

# Explicitely associate the newly created route tables to the private_ecs subnets (so they don't default to the ecs_vpc route table)
resource "aws_route_table_association" "private_ecs" {
  count          = "${var.az_count}"
  subnet_id      = "${element(aws_subnet.private_ecs.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private_ecs.*.id, count.index)}"
}

### Security

# ALB Security group
# This is the group you need to edit if you want to restrict access to your application
resource "aws_security_group" "lb" {
  name        = "tf-ecs-alb"
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

# Traffic to the ECS Cluster should only come from the ALB
resource "aws_security_group" "ecs_tasks" {
  name        = "tf-ecs-tasks"
  description = "allow inbound access from the ALB only"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"

  ingress {
    protocol        = "tcp"
    from_port       = "${var.app_port}"
    to_port         = "${var.app_port}"
    security_groups = ["${aws_security_group.lb.id}"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### ALB

resource "aws_alb" "ecs_vpc" {
  name            = "tf-ecs-chat"
  subnets         = "${aws_subnet.public_ecs.*.id}"
  security_groups = ["${aws_security_group.lb.id}"]
}

resource "aws_alb_target_group" "app" {
  name        = "tf-ecs-chat"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.ecs_vpc.id}"
  target_type = "ip"
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.ecs_vpc.id}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.app.id}"
    type             = "forward"
  }
}

### ECS

resource "aws_ecs_cluster" "ecs_vpc" {
  name = "tf-ecs-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.fargate_cpu}"
  memory                   = "${var.fargate_memory}"

  container_definitions = <<DEFINITION
[
  {
    "cpu": ${var.fargate_cpu},
    "image": "${var.app_image}",
    "memory": ${var.fargate_memory},
    "name": "app",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": ${var.app_port},
        "hostPort": ${var.app_port}
      }
    ]
  }
]
DEFINITION
}

resource "aws_ecs_service" "ecs_vpc" {
  name            = "tf-ecs-service"
  cluster         = "${aws_ecs_cluster.ecs_vpc.id}"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  desired_count   = "${var.app_count}"
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = ["${aws_security_group.ecs_tasks.id}"]
    subnets         = "${aws_subnet.private_ecs.*.id}"
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.app.id}"
    container_name   = "app"
    container_port   = "${var.app_port}"
  }

  depends_on = [
    aws_alb_listener.front_end,
  ]
}