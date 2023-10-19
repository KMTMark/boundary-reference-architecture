# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "aws_lb" "controller" {
  # Truncate any characters of name that are longer than 32 characters which is the limit imposed by Amazon for the name of a load balancer
  name               = substr("${var.tag}-controller-${random_pet.test.id}", 0, min(length("${var.tag}-controller-${random_pet.test.id}"), 32))
  load_balancer_type = "network"
  internal           = true
  security_groups    = [aws_security_group.controller_lb.id]
  subnets            = data.aws_subnets.private.ids

  tags = {
    Name = "${substr("${var.tag}-controller-${random_pet.test.id}", 0, min(length("${var.tag}-controller-${random_pet.test.id}"), 32))}"
  }
}

resource "aws_lb_target_group" "controller" {
  name     = substr("${var.tag}-controller-${random_pet.test.id}", 0, min(length("${var.tag}-controller-${random_pet.test.id}"), 32))
  port     = 9200
  protocol = "TCP"
  vpc_id   = data.aws_vpc.main.id

  stickiness {
    enabled = false
    type    = "source_ip"
  }

  health_check {
    port     = 9203
    protocol = "TCP"
  }

  tags = {
    Name = "${substr("${var.tag}-controller-${random_pet.test.id}", 0, min(length("${var.tag}-controller-${random_pet.test.id}"), 32))}"
  }
}

resource "aws_lb_target_group_attachment" "controller" {
  count            = var.num_controllers
  target_group_arn = aws_lb_target_group.controller.arn
  target_id        = aws_instance.controller[count.index].id
  port             = 9200
}

resource "aws_lb_listener" "controller" {
  load_balancer_arn = aws_lb.controller.arn
  port              = "443"
  protocol          = "TCP"
  # certificate_arn   = aws_acm_certificate.cert.arn
  # alpn_policy = "HTTP2Preferred"
  ssl_policy = ""
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.controller.arn
  }
}

resource "aws_security_group" "controller_lb" {
  vpc_id = data.aws_vpc.main.id

  tags = {
    Name = "${var.tag}-controller-lb-${random_pet.test.id}"
  }
}

resource "aws_security_group_rule" "allow_vpn_clients" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["172.30.0.0/24"]
  security_group_id = aws_security_group.controller_lb.id
}

resource "aws_security_group_rule" "allow_onelogin_servers" {
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"
  cidr_blocks = [
    "52.29.255.192/26",
    "52.48.63.0/26",
    "18.130.91.64/29",
    "23.183.112.0/24",
    "23.183.113.0/24"
  ]
  security_group_id = aws_security_group.controller_lb.id
}

resource "aws_security_group_rule" "allow_9201_workers" {
  type                     = "ingress"
  from_port                = 9201
  to_port                  = 9201
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker.id
  # cidr_blocks       = ["172.30.0.0/24"]
  security_group_id = aws_security_group.controller_lb.id
}

resource "aws_security_group_rule" "allow_egress_lb" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.controller_lb.id
}
