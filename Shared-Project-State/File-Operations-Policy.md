# File Operations Policy

- Keep task-created temporary, test, and skill-reference artifacts under `Shared-Project-State/Temporary-Files/`, `Test-Workspace/`, or `Logs/` when they cannot be placed elsewhere.
- Diagnose permission and lock failures before attempting a move.
- Prefer reversible moves/quarantine before deletion; do not overwrite destination files.
- Never self-elevate, kill unrelated processes, alter broad ACLs, or weaken host security.
- Do not store credentials or tokens in this project state.
- Preserve the owner-specified project root exactly.
