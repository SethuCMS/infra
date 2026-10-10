# Security design of this infrastructure

Where each rule from `sethucms-docs/docs/07-security.md` and `10-deployment.md` shows up in the files.

| Rule | Where it is enforced |
|---|---|
| The API never connects to customer databases | `k8s/base/networkpolicies.yaml` (`api-egress` allows only the control-plane database and HTTPS); `compose.yaml` keeps the API off the `customer-dbs` network |
| Only the worker decrypts secrets | `terraform/aws/iam.tf` (only the worker role may use the vault key); `kms.tf` also **denies** the API role in the key policy |
| The worker cannot be tricked into reaching internal services or stealing cloud credentials | `worker-egress` network policy blocks the metadata address and the cluster's own ranges; nodes require IMDSv2 with hop limit 1 (`eks.tf`) |
| Fixed addresses for customer allowlists | One NAT gateway with a fixed address per zone (`network.tf`, output `egress_ip_addresses`) |
| Secrets are never in files, state or images | Secrets Manager containers are empty in Terraform; pods read from a Kubernetes Secret filled by External Secrets; `.env` is git-ignored |
| Everything is encrypted at rest and in transit | KMS keys for database, queue, logs, images and Kubernetes secrets; `rds.force_ssl=1`; the queue refuses non-TLS requests |
| Containers are locked down | Non-root, read-only filesystem, all capabilities dropped, no privilege escalation, `restricted` Pod Security level, seccomp on |
| The database is not reachable from outside | Isolated subnets with no internet route; security group only admits the cluster |
| No accidental deletion | `deletion_protection`, final snapshots, 30-day key deletion window |
| Images cannot be silently replaced | ECR tags are immutable, images are scanned on push |
| Network activity is recorded | VPC flow logs; EKS audit logs; 1 year retention |
| The Kubernetes API is not open to the internet | Private by default; if made public, `0.0.0.0/0` is refused by a validation rule |

## Known gaps (be honest with yourself)

- The network policies need a network plugin that enforces them. The Terraform turns this on for the AWS VPC CNI; check it with a test pod before trusting it.
- The worker's outbound rule is broad on purpose (customers' databases can be anywhere). The protection is the exceptions list plus the application's own address checks (`packages/network-guard`, not written yet). Both must exist.
- Image tags in the overlays are placeholders; pin real digests when images exist.
- Secrets Manager rotation is not configured for the application secrets.
- Only AWS has Terraform. Google Cloud and Azure are described in `docs/10-deployment.md` but not provided here.
- Nothing has been applied to a real account. The Kubernetes manifests were validated against the Kubernetes schema and compose was validated; the Terraform was checked for formatting and consistent references only, not with `terraform validate`.
