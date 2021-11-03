output "alb_hostname" {
  value = "${aws_alb.ecs_vpc.dns_name}"
}

output "nlb_hostname" {
  value = "${aws_lb.ecs_nlb.dns_name}"
}