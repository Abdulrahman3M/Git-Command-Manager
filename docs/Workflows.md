# Workflows

## Select A Workspace

Enter An Existing Folder Path. The App Reports Whether It Is A Git Worktree. It Never Runs git init Automatically.

## Project Management

Open The Project Management Hub From Any Interface. It Provides Local Project Setup, Repository Connection, Local Changes, Remote Synchronization, Branch Management, Repository Status, History, GitHub Account, And GitHub Page Controls.

See The [Project Management Guide](Project-Management-Guide.md) For Step-By-Step Setup, Clone, Connect, Commit, Synchronization, And GitHub Page Instructions.

## Initialize

The App Checks Whether The Folder Is Already A Repository, Previews The Metadata Location, Asks For Confirmation, Runs git init, And Verifies The Resulting Worktree.

## Status

The Dashboard Reads git status --porcelain=v1 -z --branch And Reports Staged, Unstaged, And Untracked Counts, Branch, HEAD, Remotes, And Detected Merge/Rebase/Cherry-Pick Markers.

## Stage A File

Choose One Displayed File, Preview git add -- path, And Confirm. The App Does Not Stage Everything Silently.

## Commit

The App Requires Staged Content And A Valid Git Author Identity. When Nothing Is Staged, It Offers The Individual-File Staging Flow. It Asks For A Nonempty Commit Message, Shows Staged Diff Statistics And The Command, Confirms, Then Verifies That HEAD Changed. A Commit Remains Local; Pushing Is A Separate Action.

## Branch

Enter A Branch Name, Validate It With git check-ref-format --branch, Preview git switch -c, And Confirm.

## Remote And Synchronization

Adding A Remote Hides The URL In Confirmation And Result Messages. Fetch Is Read-Only With Respect To Working Files. Pull Uses --ff-only. Push Always Asks Before Sending Commits And Never Adds Force Flags.

Project Management Also Supports GitHub URL Preflight, Remote Verification And Editing, Explicit Upstream Tracking, And A Read-Only Status Snapshot With Ahead/Behind Counts.

## Recovery

Restore Targets One Explicitly Named Working-Tree File And Requires Confirmation. Revert Creates A New Reversing Commit. Reflog Is Available Through The Shared Command Explorer.

## All Commands

The Explorer Derives Command Names From git help -a, Categorizes Recognized Commands, And Includes Unclassified Commands. Generic Arguments Are Currently Space-Separated Tokens; Commands Requiring Special Interactive Input Are Not Given Dedicated Wizards.
