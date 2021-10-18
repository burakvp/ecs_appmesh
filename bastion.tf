resource "aws_instance" "bastion" {
  ami                         = "ami-0133407e358cc1af0"
  key_name                    = "${aws_key_pair.bastion_key.key_name}"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = ["${aws_security_group.bastion-sg.id}"]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public_ecs.0.id
}

resource "aws_security_group" "bastion-sg" {
  name   = "bastion-security-group"
  vpc_id = "${aws_vpc.ecs_vpc.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["69.181.181.129/32"]
    ipv6_cidr_blocks = ["2607:fb90:9eb8:9ba4:f06d:2670:16e9:8b03/128"]
  }

  egress {
    protocol    = -1
    from_port   = 0 
    to_port     = 0 
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion"
  public_key = var.bastion_pubkey
}

output "bastion_public_ip" {
  value = "${aws_instance.bastion.public_ip}"
}