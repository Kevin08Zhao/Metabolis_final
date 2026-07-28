# Repository Agent Rules

## GitHub delivery workflow

- For any task that actually modifies repository files, commit and publish the verified changes to `Kevin08Zhao/Metabolis_final` unless the user explicitly requests local-only work.
- Use `main` as the default target branch.
- Stage only files within the current task's scope, and preserve unrelated working-tree changes.
- Before committing, review the complete diff, check for secrets and temporary files, and record the relevant test or validation results.
- Prefer pushing directly to `main`. If branch protection rejects the push, create a `codex/<short-task-name>` branch, push it, and open a pull request targeting `main`.
- Announce completion only after verifying the published commit or merged pull request on the remote `main` branch.
- Read-only analysis and question-answering tasks do not create commits.
- Never force-push, perform destructive resets, or expose credentials.
