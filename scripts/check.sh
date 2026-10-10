#!/usr/bin/env sh
# Checks everything in this repo that can be checked without a cloud account.
# Uses whichever of docker, kustomize, kubeconform and terraform/tofu are installed, and says what it skipped.
set -eu
cd "$(dirname "$0")/.."
have() { command -v "$1" >/dev/null 2>&1; }
fail=0

if have docker; then
  tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
  sed -e 's/^\(CONTROL_PLANE_DB_PASSWORD\|TEST_PG_PASSWORD\|SESSION_SECRET\)=$/\1=placeholder/' .env.example > "$tmp"
  if docker compose --env-file "$tmp" --profile testdb --profile app config >/dev/null; then echo "ok    compose.yaml"; else echo "FAIL  compose.yaml"; fail=1; fi
else echo "skip  compose.yaml (docker not installed)"; fi

KUSTOMIZE=""
if have kustomize; then KUSTOMIZE="kustomize build"; elif have kubectl; then KUSTOMIZE="kubectl kustomize"; fi
if [ -n "$KUSTOMIZE" ]; then
  for dir in k8s/base k8s/overlays/staging k8s/overlays/production; do
    if out=$($KUSTOMIZE "$dir"); then
      if have kubeconform; then
        if printf '%s\n' "$out" | kubeconform -strict -summary -kubernetes-version 1.30.0 >/dev/null; then echo "ok    $dir"; else echo "FAIL  $dir (schema)"; fail=1; fi
      else echo "ok    $dir (builds; kubeconform not installed, schema not checked)"; fi
    else echo "FAIL  $dir (kustomize build)"; fail=1; fi
  done
else echo "skip  k8s (kustomize/kubectl not installed)"; fi

TF=""; if have terraform; then TF=terraform; elif have tofu; then TF=tofu; fi
if [ -n "$TF" ]; then
  if $TF fmt -check -recursive terraform >/dev/null; then echo "ok    terraform fmt"; else echo "FAIL  terraform fmt (run: $TF fmt -recursive terraform)"; fail=1; fi
  if (cd terraform/aws && $TF init -backend=false -input=false >/dev/null 2>&1 && $TF validate >/dev/null 2>&1); then echo "ok    terraform validate"; else echo "FAIL  terraform validate (run it by hand to see why)"; fail=1; fi
else echo "skip  terraform (terraform/tofu not installed)"; fi

exit $fail
