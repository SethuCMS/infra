# Deploying to AWS

Do staging first. Every command here is run by you; nothing in this repo applies itself.

## Before you start

- An AWS account for each environment (staging and production in separate accounts is best) and permission to create IAM roles, a VPC, EKS and RDS.
- Tools: `aws`, `terraform` (1.6 or newer), `kubectl`, `kustomize` (or `kubectl kustomize`), `docker`.
- An S3 bucket with versioning and encryption, and a DynamoDB table (key `LockID`) for Terraform state.
- A sign-in provider (OIDC) for the admin UI, and a domain name.

## 1. Create the infrastructure

```bash
cd terraform/aws
cp backend.hcl.example backend.hcl            # fill in your state bucket
cp terraform.tfvars.example terraform.tfvars  # choose staging or production sizes
terraform init -backend-config=backend.hcl
terraform plan -out plan.out                  # read it; nothing is created yet
terraform apply plan.out
```

Takes about 20 minutes. Keep the output: `terraform output`.

## 2. Tell customers your egress addresses

`terraform output egress_ip_addresses` lists the fixed addresses the worker connects from. Customers add them to their database allowlists. They do not change unless you destroy the NAT gateways.

## 3. Fill in the secrets

Terraform creates empty secret containers so values never enter its state:

```bash
aws secretsmanager put-secret-value --secret-id sethucms/staging/app/session-secret --secret-string "$(openssl rand -base64 48)"
```

For `database-url`: fetch the admin password once (`terraform output database_admin_secret_arn`), connect from inside the VPC, create a limited application user, and store that user's connection string. Do not run the application as the admin user.

## 4. Connect to the cluster and install the add-ons

```bash
aws eks update-kubeconfig --name "$(terraform output -raw cluster_name)"
```

Install, using each project's own instructions: **ingress-nginx** (namespace `ingress-nginx`, the network policies expect this name), **cert-manager** (for the TLS certificate `sethucms-tls`), and the **External Secrets Operator**. Then apply `k8s/examples/external-secret.yaml` after setting the right secret names.

## 5. Build and publish the images

```bash
aws ecr get-login-password | docker login --username AWS --password-stdin "<account>.dkr.ecr.<region>.amazonaws.com"
# From the repositories' parent folder:
docker build -f sethucms-infra/docker/Dockerfile.api    -t <ecr-url>/api:1.0.0    sethucms
docker build -f sethucms-infra/docker/Dockerfile.worker -t <ecr-url>/worker:1.0.0 sethucms
docker build -f sethucms-infra/docker/Dockerfile.admin  --build-context infra=sethucms-infra/docker \
  --build-arg VITE_API_URL=https://cms.example.com -t <ecr-url>/admin:1.0.0 sethucms-admin
docker push <ecr-url>/api:1.0.0   # and worker, admin
```

(`apps/api` and `apps/worker` are not written yet, so those two builds will fail until they are.)

## 6. Deploy

Edit `k8s/overlays/<env>/kustomization.yaml`: image names and tags (use digests once you can), the host name, the role ARNs (`terraform output api_role_arn worker_role_arn`), and the address ranges (`terraform output vpc_cidr`). Then:

```bash
kustomize build k8s/overlays/staging | kubectl diff -f -      # review
kustomize build k8s/overlays/staging | kubectl apply -f -
kubectl -n sethucms rollout status deploy/api deploy/worker deploy/admin
```

## 7. Check it works

```bash
curl -fsS https://staging.cms.example.com/v1/health
kubectl -n sethucms get pods,hpa,pdb,networkpolicy
```

Then run the end-to-end tests against staging before you promote anything to production.

## Tearing down a throwaway environment

Set `deletion_protection = false` in `terraform.tfvars`, apply, then `terraform destroy`. KMS keys are scheduled for deletion after 30 days, not immediately.
