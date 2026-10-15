# Workflows

## Select A Workspace

Enter an existing folder path. The app reports whether it is a Git worktree. It never runs `git init` automatically.

## Initialize

The app checks whether the folder is already a repository, previews the metadata location, asks for confirmation, runs `git init`, and verifies the resulting worktree.

## Status

The dashboard reads `git status --porcelain=v1 -z --branch` and reports staged, unstaged, and untracked counts, branch, HEAD, remotes, and detected merge/rebase/cherry-pick markers.

## Stage A File

Choose one displayed file, preview `git add -- <path>`, and confirm. The app does not stage everything silently.

## Commit

The app requires staged content and a valid Git author identity. When nothing is staged, it offers the individual-file staging flow. It asks for a nonempty commit message, shows staged diff statistics and the command, confirms, then verifies that HEAD changed. A commit remains local; pushing is a separate action.

## Branch

Enter a branch name, validate it with `git check-ref-format --branch`, preview `git switch -c`, and confirm.

## Remote And Synchronization

Adding a remote hides the URL in confirmation and result messages. Fetch is read-only with respect to working files. Pull uses `--ff-only`. Push always asks before sending commits and never adds force flags.

## Recovery

Restore targets one explicitly named working-tree file and requires confirmation. Revert creates a new reversing commit. Reflog is available through the shared command explorer.

## All Commands

The explorer derives command names from `git help -a`, categorizes recognized commands, and includes unclassified commands. Generic arguments are currently space-separated tokens; commands requiring special interactive input are not given dedicated wizards.
