# network

Terraform port of `routebox-infra/cfn/network/template.yaml`. Builds a single-region VPC for one Routebox environment: VPC, three public + three private subnets across the first three AZs, an internet gateway, an optional NAT gateway, route tables, and the four "default" security groups (`alb`, `ecs`, `rds`, `jenkins`) that the rest of the infra references.

This module is called once per environment from `environments/<env>/`. `dev`, `staging`, and `prod` are separate stack instances in the **same** AWS account, scoped from each other by VPC and tags.

## Usage

```hcl
module "network" {
  source = "../../network"

  environment          = "dev"
  vpc_cidr             = "10.10.0.0/16"
  public_subnet_cidrs  = ["10.10.0.0/22", "10.10.4.0/22", "10.10.8.0/22"]
  private_subnet_cidrs = ["10.10.16.0/20", "10.10.32.0/20", "10.10.48.0/20"]
  cost_center          = "platform-dev"
}
```

## Inputs

| Name                   | Type           | Default      | Description |
|------------------------|----------------|--------------|-------------|
| `environment`          | `string`       | _(required)_ | One of `dev`, `staging`, `prod`. Drives `Name` tags. |
| `vpc_cidr`             | `string`       | _(required)_ | CIDR block for the VPC. /16 in practice. |
| `public_subnet_cidrs`  | `list(string)` | _(required)_ | Three public subnet CIDRs, ordered `[a, b, c]`. |
| `private_subnet_cidrs` | `list(string)` | _(required)_ | Three private subnet CIDRs, ordered `[a, b, c]`. |
| `cost_center`          | `string`       | `"platform"` | Cost-allocation tag value. Mirrors the CFN parameter; the env-level provider's `default_tags` is what actually applies it to every resource. |
| `enable_nat_gateway`   | `bool`         | `false`      | Provision the NAT gateway and route private subnets through it. Default off — when off, the private route table has no default route and private subnets have no internet egress. Flip on if you put workloads in private subnets that need outbound access. |

## Outputs

| Name                              | Description |
|-----------------------------------|-------------|
| `vpc_id`                          | VPC ID. |
| `vpc_cidr_block`                  | VPC CIDR block. |
| `public_subnet_ids`               | List of all three public subnet IDs, `[a, b, c]` order. |
| `public_subnet_1_id` / `2` / `3`  | Individual public subnet IDs for parity with the CFN exports. |
| `private_subnet_ids`              | List of all three private subnet IDs, `[a, b, c]` order. |
| `private_subnet_1_id` / `2` / `3` | Individual private subnet IDs for parity with the CFN exports. |
| `alb_security_group_id`           | Public ALB SG. |
| `ecs_service_security_group_id`   | ECS service tasks SG. Inbound from ALB only. |
| `rds_security_group_id`           | RDS Postgres SG. Inbound 5432 from ECS and Jenkins. |
| `jenkins_security_group_id`       | Jenkins EC2 SG. Inbound 8080 from VPC CIDR. |

## Resources created

- `aws_vpc.main` — the VPC.
- `aws_internet_gateway.main` — and its (implicit) attachment.
- `aws_subnet.public["a"|"b"|"c"]` — three public subnets, one per AZ.
- `aws_subnet.private["a"|"b"|"c"]` — three private subnets, one per AZ.
- `aws_eip.nat` + `aws_nat_gateway.main` — single NAT in `public-a`, conditional on `enable_nat_gateway`. See operational notes.
- `aws_route_table.public` + `aws_route.public_default` (→ IGW) + 3× association.
- `aws_route_table.private` + 3× association — always created. The default route to NAT (`aws_route.private_default`) is conditional on `enable_nat_gateway`; with NAT off the private route table is intentionally route-less.
- `aws_security_group.{alb,ecs,rds,jenkins}` — four SGs.
- `aws_vpc_security_group_ingress_rule.ecs_from_alb` — all TCP from ALB to ECS.
- `aws_vpc_security_group_ingress_rule.rds_from_ecs` — 5432 from ECS to RDS.
- `aws_vpc_security_group_ingress_rule.rds_from_jenkins` — 5432 from Jenkins to RDS.

The cross-SG rules are deliberately split out of the SG resources to avoid Terraform dependency cycles.

## Operational notes

- **Single NAT gateway is intentional, but it's a SPOF.** Originally there were three (one per AZ); we collapsed to one a while back to save money and never put the others back. Anything in the private subnets loses egress if the NAT or `public-a` goes down.

- **NAT defaults off.** `enable_nat_gateway = false` is the default and what dev/staging/prod ship with today. With it off, no EIP / NAT gateway is created and the private route table has no default route — private subnets cannot reach the internet at all. Workloads currently run in the public subnets (e.g. EKS nodes); private subnets are reserved for future use. Flip `enable_nat_gateway = true` in the env tfvars when something actually needs to live in private subnets.

- **EKS-aware subnet tags.** Public subnets carry `kubernetes.io/role/elb = 1`; private subnets carry `kubernetes.io/role/internal-elb = 1`. These are AWS Load Balancer Controller discovery tags and are network-layer properties — they apply whether or not an EKS cluster is up. Per-cluster `kubernetes.io/cluster/<cluster-name>` tags belong to the EKS module, which manages them via `aws_ec2_tag` so the tag's lifecycle tracks the cluster's.

- **Grandfathered CFN exports are not reproduced here.** The CFN template exports two legacy names that predate the `routebox-<env>-<resource>` convention:
  - `${env}-vpc`
  - `${env}-subnet-private-a`

  Terraform doesn't produce CloudFormation exports at all, so there's no equivalent to reproduce. The consumer stacks (`iam`, `ecs-cluster`, `rds`, `ecr`, `secrets-bootstrap`) that import these names will need to migrate off them — or the network stack will need to keep being CFN — before this module can replace the CFN one in any environment.

- **Tags.** Every resource gets `Environment`, `ManagedBy = "terraform"`, and `CostCenter` via the env-level provider's `default_tags`. Note that `ManagedBy` is now `terraform`, not `cloudformation` — that's the migration. The per-resource `Name` tag is set inside this module and matches the CFN values exactly (`routebox-<env>-vpc`, `routebox-<env>-public-a`, etc.). Subnets also keep the `Tier` tag (`public` / `private`).

- **Jenkins SG TODO.** The CFN template had a `TODO` for SSH (22) from a bastion CIDR — the bastion was never decided on, so the rule was never added. The TODO is preserved as a comment on `aws_security_group.jenkins` in `main.tf`. Don't "fix" it by opening 22 to the world.

- **AZ selection.** AZs are picked deterministically as the first three from `data "aws_availability_zones"` (state = available). This mirrors `!Select [0|1|2, !GetAZs '']` in the CFN template. The third subnet (`c`) may end up in a different physical AZ if AWS reorders the list — same risk as the CFN version.

- **ECS-from-ALB ingress is wide open.** `FromPort 0, ToPort 65535` from ALB to ECS is ported verbatim from the CFN template. Tightening to per-service ports belongs in a follow-up; this PR is fidelity-first.

## Migration notes

This module replaces `cfn/network/template.yaml` from `312school/routebox-infra`. The two repos live side by side during the migration; once all three environment root modules are validated and the consumer stacks are updated, the CFN stack can be deleted.

**Grandfathered CFN export names dropped.** The original template exported two names that predate the `routebox-<env>-<resource>` naming convention:

| CFN export | Status |
|---|---|
| `${env}-vpc` | Intentionally dropped |
| `${env}-subnet-private-a` | Intentionally dropped |

Terraform doesn't produce CloudFormation stack exports, so there's no mechanism to reproduce them even if we wanted to. The consumer stacks (`iam`, `ecs-cluster`, `rds`, `ecr`, `secrets-bootstrap`) that import these names via `Fn::ImportValue` must migrate to reading from Terraform state outputs before this module can fully replace the CFN stack in any environment.

**`enable_nat_gateway` behaviour change for dev.** The original CFN template always created a NAT gateway — it was unconditional in the Resources block. In Terraform, `enable_nat_gateway` defaults to `false`, and `environments/dev/dev.tfvars` explicitly sets it to `false`. This is a deliberate cost trade-off: dev workloads run in the public subnets, so the private subnets don't need egress. `staging` and `prod` set `enable_nat_gateway = true` to match the original CFN behaviour for those environments.
