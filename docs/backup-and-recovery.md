# Backup and recovery

## What is backed up

| What | How | Kept for |
|---|---|---|
| Control-plane database | Automated daily backups and point-in-time recovery (RDS) | `db_backup_retention_days`, default 14 |
| Final snapshot | Taken automatically when the database is deleted | Until you delete it |
| Vault key (KMS) | The key never leaves AWS. Deleting it is delayed 30 days | See below |
| Terraform state | S3 bucket with versioning | Every version |

Customer content is **not** stored here. It stays in the customers' own databases and is their responsibility to back up.

## The vault key matters more than the database backup

The connection secrets stored in the control-plane database are encrypted with the vault key. A perfect database backup is useless without that key, and anyone with the key and a copy of the database can read every secret.

- Never schedule the key for deletion unless you mean to destroy all stored secrets.
- Keep key administration in a separate AWS role from daily operations, with MFA.
- Consider a second copy of the key in another region (a KMS multi-region key) if your recovery target requires surviving the loss of a region. This repo does not create one.

## Restore the control-plane database

Restoring always creates a **new** database next to the old one; it never overwrites.

1. Pick the moment: `aws rds describe-db-instance-automated-backups`.
2. Restore to a new instance:
   ```bash
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier sethucms-<env>-control-plane \
     --target-db-instance-identifier sethucms-<env>-restore-test \
     --restore-time 2026-10-08T10:00:00Z \
     --db-subnet-group-name sethucms-<env> --no-publicly-accessible
   ```
3. Connect from inside the VPC and check the data (tenants, connections, audit log).
4. To go live on the restored copy: point `DATABASE_URL` at it (update the secret, restart the api and worker), then import it into Terraform or recreate the old resource, so Terraform and reality agree again.

## Practice it

Run a restore into a throwaway instance once a quarter and write down how long it took. A backup you have never restored is a hope, not a backup. Run the key-rotation drill (`key-rotation-drill.md`) before launch.
