resource "aws_security_group" "web-sg" {

  name = "web-sg"

  description = "web-sg"

  tags = {
    Name = "web-sg"
  }

}


resource "aws_vpc_security_group_ingress_rule" "web_ssh_from_my_ip" {

  security_group_id = aws_security_group.web-sg.id

  cidr_ipv4 = var.my_ip

  from_port = 22

  ip_protocol = "tcp"

  to_port = 22

}

resource "aws_vpc_security_group_ingress_rule" "web_ssh_from_prometheus" {

  security_group_id = aws_security_group.web-sg.id

  referenced_security_group_id = aws_security_group.prometheus-sg.id

  from_port = 22

  ip_protocol = "tcp"

  to_port = 22

}

resource "aws_vpc_security_group_ingress_rule" "web_ssh_from_grafana" {

  security_group_id = aws_security_group.web-sg.id

  referenced_security_group_id = aws_security_group.grafana-sg.id

  from_port = 22

  ip_protocol = "tcp"

  to_port = 22

}

resource "aws_vpc_security_group_ingress_rule" "web_http_from_my_ip" {

  security_group_id = aws_security_group.web-sg.id

  cidr_ipv4 = "0.0.0.0/0"

  from_port = 80

  ip_protocol = "tcp"

  to_port = 80

}

resource "aws_vpc_security_group_ingress_rule" "web_node_exporter_from_prometheus" {

  security_group_id = aws_security_group.web-sg.id

  referenced_security_group_id = aws_security_group.prometheus-sg.id

  from_port = 9100

  to_port = 9100

  ip_protocol = "tcp"

}

resource "aws_vpc_security_group_ingress_rule" "web_node_exporter_from_my_ip" {

  security_group_id = aws_security_group.web-sg.id

  cidr_ipv4 = var.my_ip

  from_port = 9100

  to_port = 9100

  ip_protocol = "tcp"

}

resource "aws_vpc_security_group_ingress_rule" "web_app_from_prometheus" {

  security_group_id = aws_security_group.web-sg.id

  referenced_security_group_id = aws_security_group.prometheus-sg.id

  from_port = 3000

  to_port = 3000

  ip_protocol = "tcp"

}

resource "aws_vpc_security_group_ingress_rule" "web_app_from_my_ip" {

  security_group_id = aws_security_group.web-sg.id

  cidr_ipv4 = var.my_ip

  from_port = 3000

  to_port = 3000

  ip_protocol = "tcp"

}


resource "aws_vpc_security_group_egress_rule" "web_allow_all_outbound_ipv4" {

  security_group_id = aws_security_group.web-sg.id

  cidr_ipv4 = "0.0.0.0/0"

  ip_protocol = "-1" # semantically equivalent to all ports

}

resource "aws_vpc_security_group_egress_rule" "web_allow_all_outbound_ipv6" {

  security_group_id = aws_security_group.web-sg.id

  cidr_ipv6 = "::/0"

  ip_protocol = "-1" # semantically equivalent to all ports

}


resource "aws_security_group" "prometheus-sg" {

  name = "prometheus-sg"

  description = "prometheus-sg"

  tags = {

    Name = "prometheus"

  }

}



resource "aws_vpc_security_group_ingress_rule" "prometheus_ssh_from_my_ip" {

  security_group_id = aws_security_group.prometheus-sg.id

  cidr_ipv4 = var.my_ip

  from_port = 22

  ip_protocol = "tcp"

  to_port = 22

}

resource "aws_vpc_security_group_ingress_rule" "prometheus_ssh_from_web" {

  security_group_id = aws_security_group.prometheus-sg.id

  referenced_security_group_id = aws_security_group.web-sg.id

  from_port = 22

  ip_protocol = "tcp"

  to_port = 22

}

resource "aws_vpc_security_group_ingress_rule" "prometheus_ssh_from_grafana" {

  security_group_id = aws_security_group.prometheus-sg.id

  referenced_security_group_id = aws_security_group.grafana-sg.id

  from_port = 22

  ip_protocol = "tcp"

  to_port = 22

}


resource "aws_vpc_security_group_ingress_rule" "prometheus_web_ui_from_my_ip" {

  security_group_id = aws_security_group.prometheus-sg.id

  cidr_ipv4 = var.my_ip

  from_port = 9090

  to_port = 9090

  ip_protocol = "tcp"

}

resource "aws_vpc_security_group_ingress_rule" "grafana_dashboard_accessing_prometheus_data" {

  security_group_id = aws_security_group.prometheus-sg.id

  referenced_security_group_id = aws_security_group.grafana-sg.id

  from_port = 9090

  ip_protocol = "tcp"

  to_port = 9090

}

resource "aws_vpc_security_group_egress_rule" "prometheus_allow_all_outbound_ipv4" {

  security_group_id = aws_security_group.prometheus-sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

}

resource "aws_vpc_security_group_egress_rule" "prometheus_allow_all_outbound_ipv6" {

  security_group_id = aws_security_group.prometheus-sg.id

  cidr_ipv6 = "::/0"

  ip_protocol = "-1" # semantically equivalent to all ports

}

resource "aws_security_group" "grafana-sg" {

  name = "grafana-sg"

  description = "grafana-sg"

  tags = {

    Name = "grafana"

  }

}

resource "aws_vpc_security_group_ingress_rule" "grafana_ssh_from_my_ip" {

  security_group_id = aws_security_group.grafana-sg.id

  cidr_ipv4 = var.my_ip

  from_port = 22

  ip_protocol = "tcp"

  to_port = 22

}

resource "aws_vpc_security_group_ingress_rule" "grafana_ssh_from_web" {

  security_group_id = aws_security_group.grafana-sg.id

  referenced_security_group_id = aws_security_group.web-sg.id

  from_port = 22

  ip_protocol = "tcp"

  to_port = 22

}

resource "aws_vpc_security_group_ingress_rule" "grafana_ssh_from_prometheus" {

  security_group_id = aws_security_group.grafana-sg.id

  referenced_security_group_id = aws_security_group.prometheus-sg.id

  from_port = 22

  ip_protocol = "tcp"

  to_port = 22

}

resource "aws_vpc_security_group_ingress_rule" "grafana_web_ui_public" {

  security_group_id = aws_security_group.grafana-sg.id

  cidr_ipv4 = "0.0.0.0/0"

  from_port = 3000

  ip_protocol = "tcp"

  to_port = 3000

}

resource "aws_vpc_security_group_egress_rule" "grafana_allow_all_outbound_ipv4" {

  security_group_id = aws_security_group.grafana-sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

}

resource "aws_vpc_security_group_egress_rule" "grafana_allow_all_outbound_ipv6" {

  security_group_id = aws_security_group.grafana-sg.id

  cidr_ipv6 = "::/0"

  ip_protocol = "-1" # semantically equivalent to all ports

}