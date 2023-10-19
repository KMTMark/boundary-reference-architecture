# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "random_pet" "test" {
  length = 1
}

locals {
  tags = {
    Name = "${var.tag}-${random_pet.test.id}"
  }

  pub_cidrs  = cidrsubnets("10.0.0.0/24", 4, 4, 4, 4)
  priv_cidrs = cidrsubnets("10.0.100.0/24", 4, 4, 4, 4)
}

variable "tag" {
  default = "boundary-test"
}

variable "boundary_bin" {
  default = "~/projects/boundary/bin"
}

variable "pub_ssh_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "priv_ssh_key_path" {
  default = ""
}

variable "num_workers" {
  default = 1
}

variable "num_controllers" {
  default = 2
}

variable "num_targets" {
  default = 1
}

variable "num_subnets_public" {
  default = 2
}

variable "num_subnets_private" {
  default = 2
}

variable "tls_cert_path" {
  default = "/etc/pki/tls/boundary/boundary.cert"
}

variable "tls_key_path" {
  default = "/etc/pki/tls/boundary/boundary.key"
}

variable "le_base_path" {
  default = "/etc/letsencrypt/live/"
}

variable "tls_disabled" {
  default = false
}

variable "kms_type" {
  default = "aws"
}

variable "vpc_name" {
  default = "boundary-poc"
}

variable "boundary_url" {
  default = "https://releases.hashicorp.com/boundary/0.14.0/boundary_0.14.0_linux_amd64.zip"
}
