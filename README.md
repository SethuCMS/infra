# sethucms-infra

Everything needed to run SethuCMS: local Docker stack, Kubernetes manifests, and Terraform for AWS.

```
compose.yaml                 local stack (control-plane Postgres, admin UI, optional sample database, api + worker)
.env.example                 settings for local use; scripts/generate-local-secrets.sh makes a real .env
docker/                      Dockerfiles for api, worker and admin, plus the admin's nginx settings
local/test-postgres-init.sql sample customer database for local testing
k8s/base/                    namespace, deployments, services, autoscaling, ingress, network policies
k8s/overlays/{staging,production}/   sizes, host names, image tags, cloud roles
k8s/examples/                things applied by hand (External Secrets)
terraform/aws/               VPC, EKS, PostgreSQL, KMS keys, queue, registries, IAM roles
docs/                        deploy guide, backup and recovery, key-rotation drill, security design
scripts/check.sh             checks everything that can be checked without a cloud account
ci/infra-ci.yml              GitHub Actions workflow (move it to .github/workflows/)
```

## Run it on your computer

```bash
sh scripts/generate-local-secrets.sh        # writes .env with fresh random secrets (git-ignored)
docker compose up -d                        # control-plane database + admin UI at http://localhost:5173
docker compose --profile testdb up -d       # also a sample customer Postgres at 127.0.0.1:54321 to connect to
docker compose --profile app up -d --build  # also the api and worker (needs apps/api and apps/worker, not written yet)
```

Every port is bound to `127.0.0.1`, so nothing is reachable from other machines.
The sample database has a read-only login, `cms_reader` (password in `local/test-postgres-init.sql`, throwaway container only).
Reset everything: `docker compose --profile testdb --profile app down -v`.

## Run it in the cloud

See [`docs/deploy-aws.md`](docs/deploy-aws.md). Short version: `terraform apply`, fill in the secrets, publish the images, `kustomize build k8s/overlays/staging | kubectl apply -f -`.

Rough sizes (check current AWS prices before relying on these): staging is two small nodes, one small database and two NAT gateways; the NAT gateways and the cluster fee are the fixed costs. Production adds a third zone, larger nodes and a standby database.

## What is checked, and what is not

`sh scripts/check.sh` runs:

| Check | Tool |
|---|---|
| `compose.yaml` is valid with every profile on | `docker compose config` |
| Kubernetes base and both overlays build and match the Kubernetes 1.30 schema | `kustomize` + `kubeconform` |
| Terraform formatting and `validate` | `terraform` or `tofu` |

At the time of writing, compose and Kubernetes pass. Terraform passes formatting and a reference check (every variable, local and resource it uses exists), but `terraform validate` and a real `plan` were **not** run, because that needs provider downloads and an AWS account. Expect to fix small things on the first `terraform plan`. Docker images were not built (no Docker daemon was available, and `apps/api` and `apps/worker` do not exist yet).

## Settings

The settings are the ones listed in `sethucms-docs/docs/10-deployment.md`, plus one new one, **`QUEUE_URL`** (the job queue between api and worker; an SQS queue on AWS). Add it to the docs. There is no local queue in `compose.yaml` yet; add one (for example ElasticMQ) when the apps need it.

## Not provided yet

- Google Cloud and Azure Terraform (the identity and networking notes are in `docs/10-deployment.md`).
- Monitoring stack (metrics, dashboards, alerts). Ship logs and metrics first; `docs/10-deployment.md` lists the alerts to create.
- A multi-region setup.
- Automatic secret rotation for the application secrets.

See `docs/security-design.md` for what each security rule maps to and the known gaps.
