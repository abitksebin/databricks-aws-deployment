# AWS Databricks Platform with Terraform and Terragrunt

Infrastructure as code for a secure Databricks platform on AWS: a workspace in a customer-managed VPC with private cluster nodes, Unity Catalog, and baseline workspace configuration. Terraform modules are orchestrated by Terragrunt, one unit per layer, with remote state in S3.

This is an independent reference implementation written from the public Databricks and AWS documentation. It is the AWS counterpart of [databricks-deployment](https://github.com/abitksebin/databricks-deployment), which does the same job on Azure.

## What gets deployed

| Unit               | Module                             | Creates                                                                                                                                                  |
|--------------------|------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `network`          | `modules/network`                  | VPC, private subnets (one per AZ), public subnet(s) for NAT, internet gateway, NAT gateway with static Elastic IP, Databricks security group, S3 gateway endpoint, optional STS/Kinesis interface endpoints |
| `workspace`        | `modules/databricks-workspace`     | Cross-account IAM role (credentials), encrypted root S3 bucket with Databricks bucket policy (storage configuration), network registration, the workspace |
| `unity-catalog`    | `modules/databricks-unity-catalog` | Metastore S3 bucket, self-assuming IAM role, metastore with default credential, workspace assignment                                                     |
| `workspace-config` | `modules/databricks-config`        | Cluster policy, `data-engineers` group, shared autoscaling cluster (spot with on-demand driver), permissions                                             |

Apply order is resolved by Terragrunt: `network` -> `workspace` -> `unity-catalog` -> `workspace-config`.

```
                 Databricks control plane (Databricks-managed)
                              |  HTTPS 443 / 8443-8451
  +---------------------------|--------------------------------------+
  |  Your AWS account         v                                      |
  |  +--------------------- VPC 10.10.0.0/16 --------------------+   |
  |  |  public subnet          private subnets (2 AZs)           |   |
  |  |  [NAT gateway] <------- [Databricks cluster nodes]        |   |
  |  |        |                        |                         |   |
  |  +--------|------------------------|-------------------------+   |
  |           v                        v                             |
  |     Internet gateway        S3 gateway endpoint                  |
  |                                    |                             |
  |   S3: workspace root        S3: Unity Catalog metastore          |
  |   IAM: cross-account role   IAM: UC access role (self-assuming)  |
  +------------------------------------------------------------------+
```

## Repository layout

```
.
├── root.hcl                          # remote state (S3 + DynamoDB lock)
├── modules/
│   ├── network/
│   ├── databricks-workspace/
│   ├── databricks-unity-catalog/
│   └── databricks-config/
├── live/
│   └── dev/
│       ├── env.hcl                   # region, prefix, state backend, tags (edit this)
│       ├── network/terragrunt.hcl
│       ├── workspace/terragrunt.hcl
│       ├── unity-catalog/terragrunt.hcl
│       └── workspace-config/terragrunt.hcl
├── scripts/
│   └── bootstrap-state.sh            # creates the Terraform state bucket and lock table
└── .github/workflows/ci.yml          # fmt, validate and shellcheck
```

To add staging or prod, copy `live/dev` to `live/<env>` and edit `env.hcl` and the unit inputs.

Providers are configured inside each module rather than in `root.hcl`, because the units need different ones: AWS only, AWS plus the account-level Databricks provider, or the workspace-level Databricks provider only.

## Prerequisites

**Tooling**

- Terraform >= 1.6
- Terragrunt (a version that supports `root.hcl`)
- AWS CLI, configured for the target account (`aws configure sso` or environment credentials)

**AWS**

- Permissions to create VPC, EC2 networking, IAM roles and policies, and S3 buckets in the target account.
- Enough vCPU quota in the chosen region for the node type (default `m5d.xlarge`, 4 vCPUs; the shared cluster can reach 12 vCPUs at maximum autoscale, plus any spot/on-demand limits that apply to your account).
- An Elastic IP address quota of at least one (the NAT gateway uses one per AZ it covers).
- A `/16` VPC CIDR that does not overlap networks you will peer or connect to later.

**Databricks**

- A Databricks **account** on AWS (the account ID is shown in the account console at `accounts.cloud.databricks.com`).
- An **OAuth service principal** that is a Databricks **account admin**, with a client secret. Create it in the account console under User management > Service principals. Workspace admin is not enough for the `workspace` and `unity-catalog` units.

## Getting started

1. **Set credentials.** Nothing secret is stored in this repository; everything comes from the environment:

   ```bash
   export DATABRICKS_ACCOUNT_ID=<account-id>
   export DATABRICKS_CLIENT_ID=<service-principal-client-id>
   export DATABRICKS_CLIENT_SECRET=<service-principal-secret>
   # plus your usual AWS credentials, e.g. AWS_PROFILE=my-profile
   ```

2. **Configure the environment.** Edit `live/dev/env.hcl`:

   - `region` and `prefix`
   - `state_bucket` (globally unique) and `state_lock_table`

3. **Create the state backend** (once per environment). Use the same values as in `env.hcl`:

   ```bash
   ./scripts/bootstrap-state.sh eu-west-2 <state_bucket> <state_lock_table>
   ```

4. **Review inputs** in each `live/dev/*/terragrunt.hcl` (CIDR, NAT gateway mode, node types, autoscale limits). If your account already has a metastore in this region, set `existing_metastore_id` in `live/dev/unity-catalog/terragrunt.hcl`.

5. **Deploy:**

   ```bash
   cd live/dev
   terragrunt run-all apply
   ```

   `terragrunt run-all plan` works for the first three units on a brand-new environment. `workspace-config` can only be planned once the workspace exists, because it queries the workspace API. If you want to plan first, apply `network`, `workspace` and `unity-catalog`, then plan the rest.

On older Terragrunt versions use `terragrunt run-all ...`; on newer ones `terragrunt run --all ...`.

## Design notes

- **Customer-managed VPC.** Nodes run in private subnets with no public IPs. Outbound traffic leaves through a NAT gateway with a static IP (`nat_public_ips` output), which is handy for firewall allow-lists.
- **Security group.** Self-referencing rules allow all traffic between cluster nodes, and egress is limited to the ports Databricks documents (443, 3306, 6666, 2443, 8443-8451).
- **Subnet sizing.** Each node uses one IP and AWS reserves 5 per subnet. The private subnets are `/20` (about 4,000 IPs each), which suits dev and moderate production use. Databricks accepts `/17` to `/26`.
- **NAT cost.** `single_nat_gateway = true` is cheapest but is a single-AZ dependency for outbound traffic. Set it to `false` in production.
- **Why `workspace-config` is a separate unit.** The workspace-level Databricks provider needs the workspace URL, which only exists after the workspace is created.
- **Why `unity-catalog` is a separate unit.** It uses the account-level Databricks provider and needs account-admin permissions.
- **No personal access tokens.** The workspace is created without a token; every unit authenticates as the same OAuth service principal.
- **IAM propagation.** A short `time_sleep` follows each new IAM role, because Databricks validates the role immediately and IAM is eventually consistent.
- **Dependency mocks.** `mock_outputs` allow `init`, `validate` and `plan` to run before upstream units exist. They are never used for `apply`.

### Unity Catalog

- Databricks allows **one metastore per region per account**. Accounts created after late 2023 may already have a regional metastore. If so, set `existing_metastore_id` and the unit only assigns the workspace to it.
- The metastore trust policy uses a self-assuming role, which Databricks requires for Unity Catalog storage credentials. The provider's `databricks_aws_unity_catalog_assume_role_policy` data source generates it.
- Catalogs, schemas and grants are not created here. They are workspace-scoped, so add a further unit using the workspace-level provider.

## Authentication

- **Local:** AWS credentials for the `aws` provider, and the three `DATABRICKS_*` environment variables above for the `databricks` provider.
- **CI/CD:** use GitHub's OIDC federation to assume an AWS role (no long-lived AWS keys) and store the Databricks service principal secret as an encrypted secret. The `ci.yml` in this repo deliberately uses no credentials: it only formats and validates.
- If `workspace-config` returns a 403, add the service principal as a workspace admin (the identity that creates a workspace is normally an admin already).

## Not included

- PrivateLink (front-end and back-end) and private DNS, needed to disable public network access to the workspace
- Customer-managed keys (KMS) for workspace storage, managed services or EBS
- Cluster log delivery, audit log delivery and CloudWatch alarms
- AWS budgets and Service Control Policies
- Identity provider group sync (SCIM) in place of the workspace-local group
- Unity Catalog catalogs, schemas, external locations and grants

## Cost

The always-on parts are the NAT gateway(s) and their Elastic IPs. The shared cluster terminates after 30 minutes idle. Interface endpoints (off by default) are charged per AZ per hour. Run `terragrunt run-all destroy` when you finish experimenting.

## Cleaning up

```bash
cd live/dev
terragrunt run-all destroy
```

Destroying the metastore fails if it contains catalogs unless `force_destroy = true` is set in `live/dev/unity-catalog/terragrunt.hcl`. Remove the state bucket and DynamoDB lock table manually afterwards.

## Contributing

1. Branch from `main`.
2. Run `terraform fmt -recursive` and `terraform validate` in each module you changed.
3. Open a pull request describing the change and the plan output.

## License

MIT. See [LICENSE](LICENSE).
