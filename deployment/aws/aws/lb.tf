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

# resource "aws_security_group_rule" "allow_onelogin_servers" {
#   type      = "ingress"
#   from_port = 443
#   to_port   = 443
#   protocol  = "tcp"
#   cidr_blocks = [
#     "52.29.255.192/26",
#     "52.48.63.0/26",
#     "18.130.91.64/29",
#     "23.183.112.0/24",
#     "23.183.113.0/24"
#   ]
#   security_group_id = aws_security_group.controller_lb.id
# }

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

## Vault

/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

resource "aws_security_group" "vault_lb" {
  count       = var.lb_type == "application" ? 1 : 0
  description = "Security group for the application load balancer"
  name        = "${var.tag}-${random_pet.test.id}-vault-lb-sg"
  vpc_id      = data.aws_vpc.main.id

  tags = merge(
    { Name = "${var.tag}-${random_pet.test.id}-vault-lb-sg" },
    var.common_tags,
  )
}

resource "aws_security_group_rule" "vault_lb_inbound" {
  count             = var.lb_type == "application" && var.allowed_inbound_cidrs != null ? 1 : 0
  description       = "Allow specified CIDRs access to load balancer on port 8200"
  security_group_id = aws_security_group.vault_lb[0].id
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  cidr_blocks       = var.allowed_inbound_cidrs
}

resource "aws_security_group_rule" "vault_lb_controllers_inbound" {
  count                    = var.lb_type == "application" && var.allowed_inbound_cidrs != null ? 1 : 0
  description              = "Allow specified CIDRs access to load balancer on port 8200"
  security_group_id        = aws_security_group.vault_lb[0].id
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.controller.id
}

resource "aws_security_group_rule" "vault_lb_outbound" {
  count                    = var.lb_type == "application" ? 1 : 0
  description              = "Allow outbound traffic from load balancer to Vault nodes on port 8200"
  security_group_id        = aws_security_group.vault_lb[0].id
  type                     = "egress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
}

locals {
  lb_security_groups = var.lb_type == "network" ? null : [aws_security_group.vault_lb[0].id]
  lb_protocol        = var.lb_type == "network" ? "TCP" : "HTTPS"
}

resource "aws_lb" "vault_lb" {
  name                       = "${var.tag}-${random_pet.test.id}-vault-lb"
  internal                   = true
  load_balancer_type         = var.lb_type
  subnets                    = data.aws_subnets.private.ids
  security_groups            = local.lb_security_groups
  drop_invalid_header_fields = var.lb_type == "application" ? true : null

  tags = merge(
    { Name = "${var.tag}-${random_pet.test.id}-vault-lb" },
    var.common_tags,
  )
}

resource "aws_lb_target_group" "vault" {
  name                 = "${var.tag}-${random_pet.test.id}-vault-tg"
  deregistration_delay = var.lb_deregistration_delay
  target_type          = "instance"
  port                 = 8200
  protocol             = local.lb_protocol
  vpc_id               = data.aws_vpc.main.id

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    protocol            = "HTTPS"
    port                = "traffic-port"
    path                = var.lb_health_check_path
    interval            = 30
  }

  tags = merge(
    { Name = "${var.tag}-${random_pet.test.id}-vault-tg" },
    var.common_tags,
  )
}

resource "aws_lb_listener" "vault" {
  load_balancer_arn = aws_lb.vault_lb.id
  port              = 8200
  protocol          = local.lb_protocol
  ssl_policy        = local.lb_protocol == "HTTPS" ? var.ssl_policy : null
  certificate_arn   = local.lb_protocol == "HTTPS" ? aws_acm_certificate.vault_le_certificate.arn : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault.arn
  }
}
