# routebox-infra

CloudFormation templates and deploy tooling for Routebox AWS infrastructure.

## What's in here

```
.
├── cfn/
│   ├── network/
│   │   ├── template.yaml
│   │   └── README.md
│   ├── iam/
│   │   ├── template.yaml
│   │   └── README.md
│   ├── ecs-cluster/
│   │   └── template.yaml
│   ├── rds/
│   │   └── template.yaml
│   ├── ecr/
│   │   └── template.yaml
│   ├── secrets-bootstrap/
│   │   └── template.yaml
│   └── params/
│       ├── dev.json
│       ├── staging.json
│       └── prod.json
├── deploy/
│   └── deploy.sh
└── README.md  ← you are here
```

Six stacks, deployed in order:

1. **`network`** — VPC, subnets (public + private across 3 AZs), route tables, IGW, NAT, default security groups.
2. **`iam`** — service roles, instance profiles, the cross-stack roles other stacks depend on. Permissions for the ECS task execution role, the Jenkins EC2 role, the RDS monitoring role.
3. **`ecs-cluster`** — the ECS cluster, the ALB, target groups, listener rules, the cluster's CloudWatch log groups.
4. **`rds`** — the shared Postgres instance, its subnet group, parameter group, security group.
5. **`ecr`** — one repository per service (5 repos).
6. **`secrets-bootstrap`** — KMS key + a few baseline secrets that apps expect to exist at boot.

ECS **task definitions** are not in here. Those are managed by Jenkins as part of each app's deploy pipeline. See [`routebox-jenkins`](https://github.com/312school/routebox-jenkins).

The CloudFront distribution for `customer-portal` is **not in here either**. It was set up manually in the console. There's a TODO to bring it in. There has been for a while.

## Deploying

```
./deploy/deploy.sh <stack> <env>
```

Where `<stack>` is one of: `network`, `iam`, `ecs-cluster`, `rds`, `ecr`, `secrets-bootstrap`.
And `<env>` is one of: `dev`, `staging`, `prod`.

What `deploy.sh` does:

1. Runs `cfn-lint` against the template
2. Looks up the params file at `cfn/params/<env>.json`
3. Runs `aws cloudformation deploy --stack-name routebox-<stack>-<env> ...`
4. Tails events until the stack reaches a terminal state

State lives in the AWS account. There's no separate state file — CloudFormation owns it. The script writes a deploy log to `~/.routebox/deploy-logs/` on the operator's machine.

> **Always use the script.** Direct `aws cloudformation` calls bypass the lint and the params-file lookup, which has caused incidents.

## Stack ordering and dependencies

`network` first. Then `iam` (depends on outputs from `network` for the security-group references). Then `ecs-cluster`, `rds`, and `ecr` in any order — they all depend on `network` and `iam` but not on each other. `secrets-bootstrap` last.

Cross-stack references use **Exports** (`!ImportValue`). Names follow the pattern `routebox-<env>-<resource>`. Some of the older exports don't follow this pattern — they're grandfathered, don't rename them, things will break.

## Environments

There are three environment values: `dev`, `staging`, `prod`. They are **not separate AWS accounts**. They're separate stack instances *in the same account*, with different parameter values. Resources are scoped from each other by:

- Different VPCs per env (the `network` stack is deployed three times)
- Different IAM roles per env (the `iam` stack is deployed three times)
- Tags (`Environment: prod` etc.) — though enforcement is inconsistent

This is known to be wrong. Multi-account is on the long-term roadmap.

## Drift

Some stacks have drifted from their templates due to incident-time hand edits in the console. The `iam` stack is the worst offender. Run `aws cloudformation detect-stack-drift` if you want to see how bad it is. You probably don't want to see how bad it is.

If you make a console change during an incident, **open a PR to bring the template into line afterwards.** This rule is honored unevenly.

## Conventions

- All resources tagged with `Environment` (`dev`, `staging`, `prod`) and `ManagedBy: cloudformation`. Older resources missing one or both — don't backfill, it's not worth it.
- Stack names: `routebox-<stack>-<env>`. Example: `routebox-network-prod`.
- Parameter files in `cfn/params/<env>.json`. Don't put secrets in here — those go in Secrets Manager. There are two secrets in here right now anyway. Don't add more.
- Templates use YAML, not JSON. Older bits of `iam/template.yaml` are still JSON-style intrinsic functions (`{ "Fn::GetAtt": [...] }`) instead of `!GetAtt`. Don't normalize them in a single PR, you'll cause merge hell with anyone else's open PRs.

## Local development

You don't deploy infrastructure locally. For local app development, use the `docker-compose.yml` in each app repo.

## CI

The `routebox-jenkins` shared library has a job (`infra-deploy`) that wraps `deploy.sh` for CI-driven deploys. In practice most infra changes get deployed by hand from a platform engineer's laptop because the Jenkins job has rough edges around the manual approval gate. The hand-deploy pattern is not great. It's what we do.

## Known issues

- `iam` stack drift (see above)
- RDS parameter group has hand-edits not reflected in `rds/template.yaml` — specifically `max_connections`. Don't redeploy `rds` without manually re-applying the parameter group change after.
- `customer-portal` CloudFront is not managed here.
- The `secrets-bootstrap` stack has a few orphaned secrets from services that no longer exist. Cleaning them up requires checking with each app team — nobody's bothered.

For more context on any of the above, read [`routebox-platform-docs/notes/handover.md`](https://github.com/312school/routebox-platform-docs/blob/main/notes/handover.md).
