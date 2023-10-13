# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "boundary_scope" "global" {
  global_scope = true
  name         = "global"
  scope_id     = "global"
}

resource "boundary_scope" "org" {
  scope_id    = boundary_scope.global.id
  name        = "organization"
  description = "Organization scope"
}

// create a project for core infrastructure
resource "boundary_scope" "core_infra" {
  name        = "core_infra"
  description = "Backend infrastrcture project"
  scope_id    = boundary_scope.org.id
  # auto_create_admin_role   = true
  # auto_create_default_role = true
}

resource "boundary_scope" "kmt_org" {
  scope_id    = "global"
  name        = "Kheiron Medical"
  description = "Corp Infrastructure"
  # auto_create_default_role = true
  # auto_create_admin_role   = true
}

## Project creation

resource "boundary_scope" "kmt_project" {
  name        = "Local Dev Testing"
  description = "Manage local machines"
  scope_id    = boundary_scope.kmt_org.id
  # auto_create_admin_role   = true
  # auto_create_default_role = true
}
