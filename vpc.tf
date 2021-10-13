### Network

# Fetch AZs in the current region
data "aws_availability_zones" "available" {}

resource "aws_vpc" "ecs_vpc" {
  cidr_block = "172.17.0.0/16"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
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