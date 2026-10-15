# Project Management Guide

The Project Management Hub Is Available From Task Dashboard, Command Palette, And Assistant Console. It Uses The Same Workspace, Git Process Boundary, Validation Rules, Settings, And Safety Policy As The Rest Of The App.

## Start A Local Project

1. Open **Project Management** And Choose **New Project Setup**.
2. Choose **Create Local Project Folder**.
3. Enter A New Folder Path. Its Parent Must Already Exist.
4. Review The Destination And Confirm.

The App Creates One Empty Folder And Selects It As The Workspace. Git Is Not Initialized Automatically. Choose **Initialize Repository** Later When You Are Ready.

## Clone A GitHub Repository

1. Choose **Clone GitHub Repository**.
2. Enter A GitHub HTTPS Or SSH Repository URL.
3. Enter A New Destination Folder Whose Parent Exists.
4. The App Checks That The Remote Can Be Reached Before It Shows A Command Preview.
5. Confirm The Clone. The App Verifies The Result And Selects The New Workspace.

If A Clone Fails Partway Through, Any Partial Destination Is Preserved For Review; The App Does Not Silently Delete It.

## Connect An Existing Local Repository

1. Select The Existing Project Folder As The Workspace.
2. Open **Repository Connection** And Choose **Connect GitHub Repository**.
3. Enter A GitHub URL. The App Validates Its Form And Runs A Read-Only git ls-remote Check.
4. Confirm Adding The origin Remote. The App Verifies The Remote And Keeps Existing Commits And Files.

Use **Verify Connection** To Check A Configured Remote. Change Or Remove A Remote Only After Reviewing Its Name And Redacted URL. Removing A Remote Changes Local Configuration; It Does Not Delete The Remote Repository Or Local History.

## Review And Publish Local Changes

- **Review Status** Shows Branch, Staged/Unstaged/Untracked Counts, Upstream, Divergence, Remotes, And The Last Commit.
- **Stage Changes** Requires A Deliberate Stage-All Confirmation. Use The Existing One-File Stage Flow To Select Individual Paths.
- **Unstage Changes** Removes Selected Content From The Index But Keeps The Working Files.
- **Create A Commit** Reviews The Staged Change Summary And Commit Message. A Commit Is Local.
- **Push Changes** Is A Separate Confirmed Operation. The First Push Can Set An Upstream; Later Pushes Use The Configured Upstream.
- **Fetch** Updates Remote References Without Modifying Working Files.
- **Pull** Is Blocked When Local Changes Are Present And Uses Fast-Forward-Only Behavior.

## Branches And History

The Branch Management Section Lists Local And Remote Branches, Creates Validated Branches, Switches Branches, Renames Local Branches, Configures Upstream Tracking, And Deletes Only Merged Local Branches. The History And Recovery Section Reviews Recent Commits And Links To Existing Safe Recovery Actions.

## GitHub Repository Page

GitHub Page Management Can Create A Repository As Private By Default And Update Its Description, Homepage, Topics, Or Visibility. GitHub CLI (gh) Must Be Installed And Authenticated. The App Uses The CLI's Existing Authentication And Does Not Display Or Store Its Token.

Creating A GitHub Repository Does Not Push Commits Automatically. Review The Local State And Push As A Separate, Confirmed Step. Making A Repository Public Requires Typing The Confirmation Phrase Shown In The App.
