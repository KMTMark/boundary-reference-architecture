# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "boundary_target" "backend_servers_ssh" {
  type                     = "tcp"
  name                     = "backend_servers_ssh"
  description              = "Backend SSH target"
  scope_id                 = boundary_scope.core_infra.id
  session_connection_limit = -1
  default_port             = 22
  host_source_ids = [
    boundary_host_set_static.backend_servers.id
  ]
}

resource "boundary_target" "backend_servers_website" {
  type                     = "tcp"
  name                     = "backend_servers_website"
  description              = "Backend website target"
  scope_id                 = boundary_scope.core_infra.id
  session_connection_limit = -1
  default_port             = 8000
  host_source_ids = [
    boundary_host_set_static.backend_servers.id
  ]
}

## Kheiron Org targets

resource "boundary_target" "aws_test_servers_ssh" {
  type                     = "tcp"
  name                     = "aws_test_servers_ssh"
  description              = "AWS Backend Test SSH target"
  scope_id                 = boundary_scope.kmt_project.id
  session_connection_limit = -1
  default_port             = 22
  host_source_ids = [
    boundary_host_set_static.kmt_backend_servers.id
  ]
}

resource "boundary_target" "mlserver06_ssh" {
  type                     = "tcp"
  name                     = "ML Server 06"
  description              = "4D Test SSH target"
  scope_id                 = boundary_scope.kmt_project.id
  session_connection_limit = -1
  default_port             = 22
  host_source_ids = [
    boundary_host_set_static.kmt_ml_servers.id
  ]
}
