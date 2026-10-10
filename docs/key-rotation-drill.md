# Key rotation drill

Run this in staging before launch, then once a year. The goal is to find out, calmly, that rotation works.

## What rotates by itself

AWS rotates the key material of both KMS keys every year (`enable_key_rotation = true`). Old material is kept, so old data stays readable. You do not have to do anything for that.

## What the drill covers

Rotating the **application's envelope keys**: each connection's secret is encrypted with its own data key, and each data key is encrypted with the vault key. Re-wrapping means decrypting every data key and encrypting it again under the current key version.

1. Write down the current number of connections and pick three to verify (by their ids).
2. Run the platform's re-wrap job (`pnpm --filter @sethucms/worker rewrap-keys --dry-run`, then without `--dry-run`). *(This command belongs to the worker app, which is not written yet. Keep this step as the acceptance test for it.)*
3. For each of the three connections, run a read through the API. It must still succeed.
4. Check the audit log: one `key.rewrap` entry per connection, no entry with plaintext secrets.
5. Revoke the worker's access in IAM for five minutes (detach the `worker` role policy). Reads on a connection must now fail with a clear error and no secret in the logs. Re-attach it and confirm recovery.

## Pass criteria

- All sampled connections still work after the re-wrap.
- Nothing secret appears in logs or the audit trail.
- Failure with no key access is clean, and recovers without restarting pods.
- You wrote down how long it took and what surprised you.

## If a key is suspected leaked

1. Detach the worker role's `UseVaultKey` permission so nothing can decrypt.
2. Create a new vault key, re-encrypt every connection secret under it (the re-wrap job with `--new-key`), and switch `KMS_KEY_REF`.
3. Ask customers to rotate their database passwords. The old ones must be treated as exposed.
4. Schedule the old key for deletion only after step 3.
