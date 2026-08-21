# Backend State Migration (one-time)

## Why this is needed

The 23 AWS resources were first deployed with `terraform init -backend=false`,
so **Terraform saved no state**. Without saved state, the next `terraform apply`
tries to *re-create* resources that already exist and fails with
`ResourceAlreadyExists`. That blocks every future infrastructure change —
including adding the score-submission route the app needs.

## What was changed

1. **Remote state (S3)** — `infrastructure/aws_main.tf` now has an S3 `backend`
   block (`bucket = iq-games-tfstate-880453910905`). State now persists across
   runs.
2. **State bucket bootstrap** — the workflow creates that bucket automatically
   (idempotent) before `terraform init`.
3. **Adopt existing resources** — a new workflow step runs `terraform import`
   for each of the 23 existing resources so Terraform manages them instead of
   trying to recreate them. It is **idempotent** (skips anything already in
   state) and **non-destructive** (import only records existing resources).
4. **Score route** — a `$default` catch-all route was added so `POST` (submit
   score) and the `/users` endpoints reach the Lambda. Only this new route gets
   created on apply; everything else is adopted.

## How to run the migration

Push to `main` (or merge a PR). The `terraform-apply` job will:

1. Create the state bucket (if missing).
2. `terraform init` against the S3 backend.
3. Import the 23 existing resources into state.
4. `terraform apply` — this only **adds the new `$default` route**.

There is **no user data** in the system yet, so this migration is safe.

## Verify after the run

```bash
# Submit a test score (should now succeed):
curl -X POST "https://onll8tjd6h.execute-api.ap-south-1.amazonaws.com/dev/leaderboard/memory_game" \
  -H "Content-Type: application/json" \
  -d '{"userId":"test-1","gameId":"memory_game","score":950,"displayName":"Tester"}'

# Read it back:
curl "https://onll8tjd6h.execute-api.ap-south-1.amazonaws.com/dev/leaderboard/memory_game?gameId=memory_game&limit=10"
```

The second call should list the `Tester` entry. The app's **Submit score**
button will then work end-to-end.

## Rollback

If anything looks wrong, the previous state bucket versioning is enabled, and
because the migration only *adds* one route, reverting the `$default` route
resource and re-applying restores the prior API surface. No resources are
deleted by this migration.
