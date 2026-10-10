#!/usr/bin/env sh
# Writes .env for local development with fresh random secrets. Safe to re-run: it never overwrites an existing .env.
set -eu
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  echo ".env already exists; leaving it alone. Delete it first if you want new secrets."
  exit 0
fi

random() { head -c 32 /dev/urandom | base64 | tr -d '/+=\n' | head -c 40; }
b64() { head -c 32 /dev/urandom | base64 | tr -d '\n'; }          # 32 random bytes, base64 (what the gateway expects)
hex() { head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }     # 64 hex characters

umask 077
sed \
  -e "s|^CONTROL_PLANE_DB_PASSWORD=.*|CONTROL_PLANE_DB_PASSWORD=$(random)|" \
  -e "s|^TEST_PG_PASSWORD=.*|TEST_PG_PASSWORD=$(random)|" \
  -e "s|^SESSION_SECRET=.*|SESSION_SECRET=$(random)|" \
  -e "s|^SETHUCMS_VAULT_KEY=.*|SETHUCMS_VAULT_KEY=$(b64)|" \
  -e "s|^SETHUCMS_CURSOR_SECRET=.*|SETHUCMS_CURSOR_SECRET=$(b64)|" \
  -e "s|^SETHUCMS_PREVIEW_SECRET=.*|SETHUCMS_PREVIEW_SECRET=$(b64)|" \
  -e "s|^SETHUCMS_ADMIN_TOKEN=.*|SETHUCMS_ADMIN_TOKEN=$(hex)|" \
  .env.example > .env
echo "Wrote .env (readable only by you). Next: docker compose --profile gateway --profile testdb up -d --build"
