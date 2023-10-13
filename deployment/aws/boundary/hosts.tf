# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

## Demo Org

resource "boundary_host_catalog_static" "backend_servers" {
  name        = "backend_servers"
  description = "Web servers for backend team"
  scope_id    = boundary_scope.core_infra.id
}

resource "boundary_host_static" "backend_servers" {
  for_each        = var.target_ips
  name            = "backend_server_${each.value}"
  description     = "Backend server #${each.value}"
  address         = each.key
  host_catalog_id = boundary_host_catalog_static.backend_servers.id
}

resource "boundary_host_set_static" "backend_servers" {
  name            = "backend_servers"
  description     = "Host set for backend servers"
  host_catalog_id = boundary_host_catalog_static.backend_servers.id
  host_ids        = [for host in boundary_host_static.backend_servers : host.id]
}

## KMT Org

resource "boundary_host_catalog_static" "kmt_backend_servers" {
  name        = "backend_servers"
  description = "Web servers for backend team"
  scope_id    = boundary_scope.kmt_project.id
}

resource "boundary_host_static" "kmt_backend_servers" {
  for_each        = var.target_ips
  name            = "backend_server_${each.value}"
  description     = "Backend server #${each.value}"
  address         = each.key
  host_catalog_id = boundary_host_catalog_static.kmt_backend_servers.id
}

resource "boundary_host_set_static" "kmt_backend_servers" {
  name            = "backend_servers"
  description     = "Host set for backend servers"
  host_catalog_id = boundary_host_catalog_static.kmt_backend_servers.id
  host_ids        = [for host in boundary_host_static.kmt_backend_servers : host.id]
}