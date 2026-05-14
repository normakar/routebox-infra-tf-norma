# rds

Terraform port of `cfn/rds/template.yaml` from `312school/routebox-infra`. Provisions a single-AZ (or Multi-AZ) RDS Postgres instance for one Routebox environment: a DB subnet group across all three private subnets, a Postgres 14 parameter group, and the instance itself. Called once per environment from `environments/<env>/`.

## Usage

```hcl
module "rds" {
  source = "../../rds"

  environment           = "dev"
  private_subnet_ids    = module.network.private_subnet_ids
  rds_security_group_id = module.network.rds_security_group_id
  cost_center           = "platform-dev"

  db_instance_class    = "db.t3.small"
  db_allocated_storage = 20
  db_engine_version    = "14.10"
  db_master_username   = "routebox_admin"
  db_master_password   = var.rds_master_password  # from TF_VAR_rds_master_password

  multi_az              = false
  backup_retention_days = 1
  skip_final_snapshot   = true
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `environment` | `string` | _(required)_ | One of `dev`, `staging`, `prod`. Drives resource names and tags. |
| `private_subnet_ids` | `list(string)` | _(required)_ | Three private subnet IDs for the DB subnet group. Pass `module.network.private_subnet_ids`. |
| `rds_security_group_id` | `string` | _(required)_ | ID of the RDS security group from the network module. |
| `db_instance_class` | `string` | `"db.t3.medium"` | RDS instance class. |
| `db_allocated_storage` | `number` | `100` | Allocated storage in GiB (20–1000). |
| `db_engine_version` | `string` | `"14.10"` | Postgres engine version. Pinned — coordinate upgrades with ops-console. |
| `db_master_username` | `string` | `"routebox_admin"` | Master username. |
| `db_master_password` | `string` | _(required)_ | Master password. Marked `sensitive`. Use `TF_VAR_rds_master_password` at apply time. |
| `multi_az` | `bool` | `false` | Enable Multi-AZ standby. True for prod. |
| `backup_retention_days` | `number` | `7` | Automated backup retention in days. |
| `deletion_protection` | `bool` | `false` | Prevent API deletion. True for prod. |
| `performance_insights_enabled` | `bool` | `false` | Enable Performance Insights. True for prod. |
| `performance_insights_retention_days` | `number` | `7` | Performance Insights retention (days). Only used when enabled. |
| `monitoring_interval` | `number` | `0` | Enhanced monitoring interval in seconds. `0` disables it. `60` for prod. When > 0, the module looks up the `routebox-<env>-rds-monitoring` IAM role by name. |
| `skip_final_snapshot` | `bool` | `false` | Skip the final snapshot on deletion. True for dev; false for staging/prod. |
| `max_connections` | `number` | `null` | Override `max_connections` in the parameter group. `null` = RDS engine default. Set to `400` for prod. |
| `cost_center` | `string` | `"platform"` | Cost-allocation tag value. |

## Outputs

| Name | Description |
|---|---|
| `db_endpoint` | RDS instance endpoint hostname. Equivalent to CFN export `routebox-<env>-db-endpoint`. |
| `db_port` | RDS instance port. Equivalent to CFN export `routebox-<env>-db-port`. |
| `db_instance_identifier` | RDS instance identifier. Equivalent to CFN export `routebox-<env>-db-id`. |

## Migration notes

This module replaces `cfn/rds/template.yaml` from `312school/routebox-infra`. The original stack was deployed with a dependency on the network and IAM CFN stacks via cross-stack imports (`Fn::ImportValue`). In Terraform these are replaced by module output references (network) and an IAM role data source lookup (enhanced monitoring).

**`max_connections = 400` in prod.** The original CFN template intentionally omitted `max_connections` from the parameter group, but the live prod parameter group was hand-edited to `400` and that edit was never committed back to the template. The Terraform module captures this in `var.max_connections`; `prod.tfvars` sets it to `400`. The first `terraform apply` on prod will bring the TF-managed parameter group in line with the live config.

**Enhanced monitoring role.** The `routebox-<env>-rds-monitoring` IAM role is created by the IAM CFN stack (not yet migrated). The rds module looks it up by name via a `data "aws_iam_role"` source when `monitoring_interval > 0`, so no ARN needs to be passed explicitly. Once the IAM stack is migrated to Terraform, the data source will resolve to the TF-managed role transparently.

**Password handling.** The original CFN stack received the master password via a `params/*.json` file (`NoEcho: true`). In Terraform the variable is `sensitive = true` and should be passed at apply time via the `TF_VAR_rds_master_password` environment variable rather than committed to tfvars. The placeholder values in `*.tfvars` are there for documentation only — do not use them in production.

**`deletion_protection = true` for prod.** The CFN template used an `IsProd` condition (`!If [IsProd, true, false]`) for `DeletionProtection`. In Terraform this is an explicit variable. Removing an instance with `deletion_protection = true` requires setting it to `false` and applying before destroying.

**`skip_final_snapshot`.** CFN's `DeletionPolicy: Snapshot` always takes a snapshot before deleting. Terraform's equivalent is `skip_final_snapshot = false`. Dev is set to `true` (no snapshot) as a cost trade-off. Staging and prod are `false`.
