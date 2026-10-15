# Security

- Git runs through a trusted executable path and argument arrays; the child process receives the selected working directory directly.
- Unknown commands are assigned `RequiresReview` risk. State-changing commands require confirmation; destructive flags are reviewed centrally.
- No command is run by moving the selection.
- Commit messages and paths are individual process arguments in guided flows.
- Remote URLs are not included in confirmation or success output.
- Logs record failure summaries without command output or credentials.
- The app does not install software, elevate privileges, collect telemetry, or read credentials directly.

Generic command input currently splits on whitespace. Use dedicated guided workflows when a path or argument contains spaces.
