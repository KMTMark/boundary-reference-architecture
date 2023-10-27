# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  priv_ssh_key_real = coalesce(var.priv_ssh_key_path, trimsuffix(var.pub_ssh_key_path, ".pub"))
}

resource "aws_key_pair" "boundary" {
  key_name   = "${var.tag}-${random_pet.test.id}"
  public_key = file(var.pub_ssh_key_path)

  tags = local.tags
}

data "aws_region" "current" {
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "worker" {
  count                  = var.num_workers
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.boundary.name
  subnet_id              = data.aws_subnets.private.ids[count.index]
  key_name               = aws_key_pair.boundary.key_name
  vpc_security_group_ids = [aws_security_group.worker.id]
  # associate_public_ip_address = true

  connection {
    type         = "ssh"
    user         = "ubuntu"
    private_key  = file(local.priv_ssh_key_real)
    host         = self.private_ip
    bastion_host = aws_instance.controller[count.index].private_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/pki/tls/boundary",
      "echo '${tls_private_key.boundary.private_key_pem}' | sudo tee ${var.tls_key_path}",
      "echo '${tls_self_signed_cert.boundary.cert_pem}' | sudo tee ${var.tls_cert_path}",
    ]
  }

  # provisioner "file" {
  #   source      = "${var.boundary_bin}/boundary"
  #   destination = "/tmp/boundary"
  # }

  provisioner "file" {
    source      = "${path.module}/install/apt-install.sh"
    destination = "/home/ubuntu/apt-install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 0755 /home/ubuntu/apt-install.sh",
      "sudo sh /home/ubuntu/apt-install.sh"
    ]
  }

  # provisioner "remote-exec" {
  #   inline = [
  #     "sudo mv /tmp/boundary /usr/local/bin/boundary",
  #     "sudo chmod 0755 /usr/local/bin/boundary",
  #   ]
  # }

  provisioner "file" {
    content = templatefile("${path.module}/install/worker.hcl.tpl", {
      controller_ips         = aws_instance.controller.*.private_ip
      name_suffix            = count.index
      public_ip              = self.private_ip
      private_ip             = self.private_ip
      tls_disabled           = var.tls_disabled
      tls_key_path           = var.tls_key_path
      tls_cert_path          = var.tls_cert_path
      kms_type               = var.kms_type
      kms_worker_auth_key_id = aws_kms_key.worker_auth.id
    })
    destination = "/tmp/boundary-worker.hcl"
  }

  provisioner "remote-exec" {
    inline = ["sudo mv /tmp/boundary-worker.hcl /etc/boundary-worker.hcl"]
  }

  provisioner "file" {
    source      = "${path.module}/install/install.sh"
    destination = "/home/ubuntu/install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 0755 /home/ubuntu/install.sh",
      "sudo /home/ubuntu/install.sh worker"
    ]
  }

  tags = {
    Name = "${var.tag}-worker-${random_pet.test.id}"
  }

  depends_on = [aws_instance.controller]
}


resource "aws_instance" "controller" {
  count                  = var.num_controllers
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.boundary.name
  subnet_id              = data.aws_subnets.private.ids[count.index]
  key_name               = aws_key_pair.boundary.key_name
  vpc_security_group_ids = [aws_security_group.controller.id]
  # associate_public_ip_address = true

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(local.priv_ssh_key_real)
    host        = self.private_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/pki/tls/boundary",
      "echo '${tls_private_key.boundary.private_key_pem}' | sudo tee ${var.tls_key_path}",
      "echo '${tls_self_signed_cert.boundary.cert_pem}' | sudo tee ${var.tls_cert_path}",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/letsencrypt/live/${aws_route53_zone.boundary_base_domain.name}",
      "echo '${acme_certificate.boundary_certificate.certificate_pem}' | sudo tee ${var.le_base_path}${aws_route53_zone.boundary_base_domain.name}/fullchain.pem",
      "echo '${tls_private_key.cert_private_key.private_key_pem}' | sudo tee ${var.le_base_path}${aws_route53_zone.boundary_base_domain.name}/privkey.pem",
    ]
  }

  # provisioner "file" {
  # source      = "${var.boundary_bin}/boundary"
  # destination = "/tmp/boundary"
  # }

  provisioner "file" {
    source      = "${path.module}/install/apt-install.sh"
    destination = "/home/ubuntu/apt-install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 0755 /home/ubuntu/apt-install.sh",
      "sudo sh /home/ubuntu/apt-install.sh"
    ]
  }

  # provisioner "remote-exec" {
  #   inline = [
  #     "sudo mv /tmp/boundary /usr/local/bin/boundary",
  #     "sudo chmod 0755 /usr/local/bin/boundary",
  #   ]
  # }

  provisioner "file" {
    content = templatefile("${path.module}/install/controller.hcl.tpl", {
      name_suffix            = count.index
      db_endpoint            = aws_db_instance.boundary.endpoint
      private_ip             = self.private_ip
      tls_disabled           = var.tls_disabled
      tls_key_path           = var.tls_key_path
      tls_cert_path          = var.tls_cert_path
      kms_type               = var.kms_type
      kms_worker_auth_key_id = aws_kms_key.worker_auth.id
      kms_recovery_key_id    = aws_kms_key.recovery.id
      kms_root_key_id        = aws_kms_key.root.id
      le_base_path           = var.le_base_path
      base_domain            = aws_route53_zone.boundary_base_domain.name
    })
    destination = "/tmp/boundary-controller.hcl"
  }

  provisioner "remote-exec" {
    inline = ["sudo mv /tmp/boundary-controller.hcl /etc/boundary-controller.hcl"]
  }

  provisioner "file" {
    source      = "${path.module}/install/install.sh"
    destination = "/home/ubuntu/install.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 0755 /home/ubuntu/install.sh",
      "sudo sh /home/ubuntu/install.sh controller"
    ]
  }

  tags = {
    Name = "${var.tag}-controller-${random_pet.test.id}"
  }
  depends_on = [acme_certificate.boundary_certificate]
}

resource "aws_security_group" "controller" {
  vpc_id = data.aws_vpc.main.id

  tags = {
    Name = "${var.tag}-controller-${random_pet.test.id}"
  }
}

resource "aws_security_group_rule" "allow_ssh_controller" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["172.30.0.0/24"]
  security_group_id = aws_security_group.controller.id
}

resource "aws_security_group_rule" "allow_9200_lb_controller" {
  type                     = "ingress"
  from_port                = 9200
  to_port                  = 9200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.controller_lb.id
  security_group_id        = aws_security_group.controller.id
}

resource "aws_security_group_rule" "allow_9201_lb_controller" {
  type                     = "ingress"
  from_port                = 9201
  to_port                  = 9201
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.controller_lb.id
  security_group_id        = aws_security_group.controller.id
}

resource "aws_security_group_rule" "allow_9203_lb_hc_controller" {
  type                     = "ingress"
  from_port                = 9203
  to_port                  = 9203
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.controller_lb.id
  security_group_id        = aws_security_group.controller.id
}

resource "aws_security_group_rule" "allow_9201_worker_controller" {
  type                     = "ingress"
  from_port                = 9201
  to_port                  = 9201
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker.id
  # cidr_blocks       = ["172.30.0.0/24"]
  security_group_id = aws_security_group.controller.id
}

resource "aws_security_group_rule" "allow_9200_vault_controller" {
  type                     = "ingress"
  from_port                = 9200
  to_port                  = 9200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault.id
  security_group_id        = aws_security_group.controller.id
}

resource "aws_security_group_rule" "allow_egress_controller" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.controller.id
}

resource "aws_security_group" "worker" {
  vpc_id = data.aws_vpc.main.id

  tags = {
    Name = "${var.tag}-worker-${random_pet.test.id}"
  }
}

resource "aws_security_group_rule" "allow_vpn_ssh_worker" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["172.30.0.0/24"]
  security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "allow_controller_ssh_worker" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.controller.id
  # cidr_blocks       = ["172.30.0.0/24"]
  security_group_id = aws_security_group.worker.id
}


resource "aws_security_group_rule" "allow_web_worker" {
  type              = "ingress"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  cidr_blocks       = ["172.30.0.0/24"]
  security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "allow_9202_worker" {
  type              = "ingress"
  from_port         = 9202
  to_port           = 9202
  protocol          = "tcp"
  cidr_blocks       = ["172.30.0.0/24"]
  security_group_id = aws_security_group.worker.id
}

resource "aws_security_group_rule" "allow_egress_worker" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.worker.id
}

# Example resource for connecting to through boundary over SSH
resource "aws_instance" "target" {
  count                  = var.num_targets
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.private.ids[count.index]
  key_name               = aws_key_pair.boundary.key_name
  vpc_security_group_ids = [aws_security_group.target.id]

  tags = {
    Name = "${var.tag}-target-${random_pet.test.id}"
  }
}

resource "aws_security_group" "target" {
  vpc_id = data.aws_vpc.main.id

  tags = {
    Name = "${var.tag}-target-${random_pet.test.id}"
  }
}

resource "aws_security_group_rule" "allow_worker_ssh_target" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker.id
  security_group_id        = aws_security_group.target.id
}

resource "aws_security_group_rule" "allow_worker_web_target" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker.id
  security_group_id        = aws_security_group.target.id
}

## Vault Config

/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

resource "aws_security_group" "vault" {
  name   = "${var.tag}-${random_pet.test.id}-vault-sg"
  vpc_id = data.aws_vpc.main.id

  tags = merge(
    { Name = "${var.tag}-${random_pet.test.id}-vault-sg" },
    var.common_tags,
  )
}

resource "aws_security_group_rule" "vault_internal_api" {
  description       = "Allow Vault nodes to reach other on port 8200 for API"
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  self              = true
}

resource "aws_security_group_rule" "vault_internal_raft" {
  description       = "Allow Vault nodes to communicate on port 8201 for replication traffic, request forwarding, and Raft gossip"
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 8201
  to_port           = 8201
  protocol          = "tcp"
  self              = true
}

# The following data source gets used if the user has
# specified a network load balancer.
# This will lock down the EC2 instance security group to
# just the subnets that the load balancer spans
# (which are the private subnets the Vault instances use)

data "aws_subnet" "subnet" {
  count = length(data.aws_subnets.private.ids)
  id    = data.aws_subnets.private.ids[count.index]
}

locals {
  subnet_cidr_blocks = [for s in data.aws_subnet.subnet : s.cidr_block]
}

resource "aws_security_group_rule" "vault_network_lb_inbound" {
  count             = var.lb_type == "network" ? 1 : 0
  description       = "Allow load balancer to reach Vault nodes on port 8200"
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  cidr_blocks       = local.subnet_cidr_blocks
}

resource "aws_security_group_rule" "vault_application_lb_inbound" {
  count                    = var.lb_type == "application" ? 1 : 0
  description              = "Allow load balancer to reach Vault nodes on port 8200"
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vault_lb[count.index].id
}

resource "aws_security_group_rule" "vault_network_lb_ingress" {
  count             = var.lb_type == "network" && var.allowed_inbound_cidrs != null ? 1 : 0
  description       = "Allow specified CIDRs access to load balancer and nodes on port 8200"
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  cidr_blocks       = var.allowed_inbound_cidrs
}

resource "aws_security_group_rule" "vault_ssh_inbound" {
  count             = var.allowed_inbound_cidrs_ssh != null ? 1 : 0
  description       = "Allow specified CIDRs SSH access to Vault nodes"
  security_group_id = aws_security_group.vault.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_inbound_cidrs_ssh
}

resource "aws_security_group_rule" "vault_outbound" {
  description       = "Allow Vault nodes to send outbound traffic"
  security_group_id = aws_security_group.vault.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "controller_vault_inbound" {
  count                    = var.lb_type == "application" ? 1 : 0
  description              = "Allow load balancer to reach Vault nodes on port 8200"
  security_group_id        = aws_security_group.vault.id
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.controller.id
}

locals {
  vault_user_data = templatefile(
    var.user_supplied_userdata_path != null ? var.user_supplied_userdata_path : "${path.module}/install/install_vault.sh.tpl",
    {
      region                = data.aws_region.current.name
      name                  = "${var.tag}-target-${random_pet.test.id}-vault-ec2"
      vault_version         = var.vault_version
      kms_key_arn           = aws_kms_key.vault.arn
      secrets_manager_arn   = aws_secretsmanager_secret.tls.arn
      leader_tls_servername = var.shared_san
    }
  )
}

resource "aws_launch_template" "vault" {
  name          = "${var.tag}-target-${random_pet.test.id}-vault"
  image_id      = var.user_supplied_ami_id != null ? var.user_supplied_ami_id : data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name != null ? var.key_name : null
  user_data     = base64encode(local.vault_user_data)
  vpc_security_group_ids = [
    aws_security_group.vault.id,
  ]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = "gp3"
      volume_size           = 100
      throughput            = 150
      iops                  = 3000
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.vault.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

resource "aws_autoscaling_group" "vault" {
  name                = "${var.tag}-${random_pet.test.id}-vault-asg"
  min_size            = var.node_count
  max_size            = var.node_count
  desired_capacity    = var.node_count
  vpc_zone_identifier = data.aws_subnets.private.ids
  target_group_arns   = [aws_lb_target_group.vault.arn]

  launch_template {
    id      = aws_launch_template.vault.id
    version = "$Latest"
  }

  tags = concat(
    [
      {
        key                 = "Name"
        value               = "${var.tag}-${random_pet.test.id}-vault-server"
        propagate_at_launch = true
      }
    ],
    [
      {
        key                 = "${var.tag}-${random_pet.test.id}-vault"
        value               = "server"
        propagate_at_launch = true
      }
    ],
    [
      for k, v in var.common_tags : {
        key                 = k
        value               = v
        propagate_at_launch = true
      }
    ]
  )
}
