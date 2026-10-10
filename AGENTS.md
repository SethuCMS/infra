# AGENTS.md — sethucms-infra

Docker, compose, Kubernetes and Terraform.

This repository is one part of SethuCMS. **Read `../sethucms/AGENTS.md` first** for the whole picture, the security rules that must not be broken, and the working agreements.

## Build and test

```sh
sh scripts/check.sh
```

## Notes

The built product is ONE container, built by sethucms/docker/Dockerfile.gateway (gateway + admin, one port). compose.yaml profile `gateway` matches it. Dockerfile.api, Dockerfile.worker, compose profile `app`, k8s/ and terraform/aws/ still follow an older, larger design (api, worker, queue) and are NOT aligned. For Kubernetes the gateway must run as one replica with a persistent volume on /data. Never run terraform apply or touch a live environment without the owner saying so.

## Always

- Run the tests for what you changed and say what you ran and what you could not run.
- Do not `git commit` or `git push` unless the owner asks.
- Never print or store a secret, token or password.
