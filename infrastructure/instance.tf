resource "aws_instance" "web" {
  ami                    = data.aws_ami.amiID.id
  instance_type          = var.instance_type
  key_name               = var.keypair
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  availability_zone      = var.zone1
  # associate_public_ip_address = false

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name    = "Infra-web"
    Project = "Infra"
  }
}

resource "aws_ec2_instance_state" "web-state" {
  instance_id = aws_instance.web.id
  state       = "stopped"
}


resource "aws_instance" "prometheus" {
  ami                    = data.aws_ami.amiID.id
  instance_type          = var.instance_type
  key_name               = var.keypair
  vpc_security_group_ids = [aws_security_group.prometheus-sg.id]
  availability_zone      = var.zone1
  # associate_public_ip_address = false

  tags = {
    Name    = "Infra-prometheus"
    Project = "Infra"
  }
}

resource "aws_ec2_instance_state" "prometheus-state" {
  instance_id = aws_instance.prometheus.id
  state       = "stopped"
}


resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amiID.id
  instance_type          = var.instance_type
  key_name               = var.keypair
  vpc_security_group_ids = [aws_security_group.grafana-sg.id]
  availability_zone      = var.zone1
  # associate_public_ip_address = false

  tags = {
    Name    = "Infra-grafana"
    Project = "Infra"
  }
}

resource "aws_ec2_instance_state" "grafana-state" {
  instance_id = aws_instance.grafana.id
  state       = "stopped"
}