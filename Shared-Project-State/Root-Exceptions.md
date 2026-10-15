# Root Exceptions

| Root Path | Tool | Why Root Is Required | Relocatable Data Routed To | Verified By |
|---|---|---|---|---|
| `src/`, `tests/`, `Start-Git-Command-Manager.ps1`, launchers | Application | Product runtime/test layout and entry point are required at root by the TUI scaffold/launchers. | Runtime scratch and agent state to `Shared-Project-State/`. | TUI validator |
| `.github/workflows/` | GitHub Actions | GitHub requires workflow definitions in this root-relative path. | Test logs to `Shared-Project-State/Logs/`. | Project layout |
