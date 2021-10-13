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
  }

  egress {
    protocol    = -1
    from_port   = 0 
    to_port     = 0 
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "bastion_key" {
  key_name   = "vitalii.burak@jmpchase.com"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNHqHEhyJVy5vlPacO1QqOdVNXJB/jSYHoSykLeK/8NvfGc7SdPi4WmvbCrBL/12qSvhVi7/8VYgclVM1QfqZ3OBLShTJSAVr5pn67Z1KrG5GALlS0qJadEmqVzjjxy9sy//WS2xAw0yxiwWjRjj0KMlAb3SBqxqeTIJVGd5DVlC091zyRCJq3G4xYGpHOPF7t3mWTJyW0jCeFQqO3fux6cqGjNG9hE3WcHDzxGjG2JofVwTjAZC/rjPRYGHF1Cg0MaJXUyJhbbMKiUooN8xxmDt5qRGKq0CzM3nuxsP3H8bV6St/DwQQTchs8Vz5XWOjHPibOjTWIQsZcfycbtckO/R3fMg7RsEzHm1dVSgqg/tDRNDJG+sFZQcM+BAf19xL5Ea3HIt5NbdQ+okTkv2fZJBRrreJh7iDf8R6Uu6whX7PRGdZ/77/qVSzrYM8Mek/UiEZ1Yn2pJrszIuBOiF7VuqcbhRP4juc7EW3KlOR3+AJXUVWSGUbyP+8Q26LWaxkkucyPGxF8u2nEQ8+tkQBpIqFXpDowCoFVR3+OFwUTnKF4IiJYB2dExwHAyfesy5BFFcyLTOYs/LdpCenqneP5ONDmlksAqLilDse2oOv7hmhjgUeqmoOA+Ukygr7R9DrU23CVxjtjIhUzeoAf3ya0KUt9mxhBd5kXOf/UllEAyQ== vitalii.burak@jmpchase.com"
}

output "bastion_public_ip" {
  value = "${aws_instance.bastion.public_ip}"
}