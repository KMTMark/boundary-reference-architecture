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

# Host Catalogs

resource "boundary_host_catalog_static" "kmt_backend_servers" {
  name        = "backend_servers"
  description = "Web servers for backend team"
  scope_id    = boundary_scope.kmt_project.id
}

resource "boundary_host_catalog_static" "kmt_ml_servers" {
  name        = "Machine Learning Servers"
  description = "Servers for ML team"
  scope_id    = boundary_scope.kmt_project.id
}

## Static Sets

resource "boundary_host_set_static" "kmt_backend_servers" {
  name            = "backend_servers"
  description     = "Host set for backend servers"
  host_catalog_id = boundary_host_catalog_static.kmt_backend_servers.id
  host_ids        = [for host in boundary_host_static.kmt_backend_servers : host.id]
}

resource "boundary_host_set_static" "kmt_ml_servers" {
  name            = "ML Servers"
  description     = "Host set for ML servers"
  host_catalog_id = boundary_host_catalog_static.kmt_ml_servers.id
  host_ids        = [boundary_host_static.mlserver06.id]
}

## Auto-Created Host Statics

resource "boundary_host_static" "kmt_backend_servers" {
  for_each        = var.target_ips
  name            = "backend_server_${each.value}"
  description     = "Backend server #${each.value}"
  address         = each.key
  host_catalog_id = boundary_host_catalog_static.kmt_backend_servers.id
}

## Manual Test Static Hosts

resource "boundary_host_static" "mlserver06" {
  name            = "ML Server 06"
  description     = "uk-4d-lpg-mlserver06.ew1.kmed.co"
  address         = "10.0.2.77"
  host_catalog_id = boundary_host_catalog_static.kmt_ml_servers.id
}
