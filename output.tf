output "alb_hostname" {
  value = "${aws_alb.ecs_vpc.dns_name}"
}