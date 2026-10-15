# Git Command Manager

Git Command Manager is a keyboard-first PowerShell terminal application for discovering and running installed Git commands with previews, risk explanations, and explicit confirmations.

## Interfaces

- **Task Dashboard** is the default interface and provides workspace state and organized actions.
- **Command Palette** searches every command discovered from the installed Git executable.
- **Assistant Console** guides users through status, initialization, and command discovery.

All interfaces use one Git process boundary, command inventory, safety policy, workspace parser, and persistent settings store. Select **Interface Mode** from the dashboard to change the active or preferred interface. Your selection is saved per user.

The dashboard and assistant provide guided workflows for status, initialization, staging one selected file, commits, branch creation, remotes, fetch, fast-forward-only pull, push, and recovery. Every discovered Git command remains available in the explorer. Generic arguments are split on spaces; use the guided workflows for file paths with spaces or complex quoting.

## Requirements

- Git on PATH
- PowerShell 7 on Windows, Linux, or macOS; Windows PowerShell 5.1 is supported on Windows
- Windows Terminal is recommended on Windows

## Run

```powershell
pwsh -NoProfile -File .\Start-Git-Command-Manager.ps1
```

Use `-Version` to print the application version. A redirected session requires `-ScriptedInput` and exits with code 2 otherwise.

## Safety

Git is started only with argument arrays and a process working directory. Read-only commands run directly; state-changing, destructive, and unclassified actions require review. Remote URLs are hidden from confirmation and success messages. The application never installs or updates Git, creates a repository without consent, or sends credentials.

## Verification Status

PowerShell 7 and Windows PowerShell 5.1 command discovery were run locally. Real interactive flicker observation, Linux execution, and GitHub CI are not yet verified.
