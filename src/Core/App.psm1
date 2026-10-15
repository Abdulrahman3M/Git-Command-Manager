# App.psm1 - Three interfaces over shared Git and safety modules.
Set-StrictMode -Version 2.0

function Get-AppVersion { param([string]$Root) return (Get-Content -LiteralPath (Join-Path $Root 'VERSION') -TotalCount 1).Trim() }
function Test-PersonName { param([string]$Text) if ([string]::IsNullOrWhiteSpace($Text)) { return 'Please type a name.' }; if ($Text.Length -gt 40) { return 'The name can have at most 40 characters.' }; return $null }
function Get-AppDesign { param([string]$Root) return @{ preset='task-dashboard'; navigation='Arrows'; icons='Auto'; colors='Full'; descriptions='Muted' } }
function Apply-AppDesign { param([string]$Root) Set-TuiMenuStyle -Navigation Arrows -Preset 'task-dashboard' -Descriptions Muted; Set-TuiColorStyle -Mode Full -Accent (Get-TuiPreset -Id 'task-dashboard').Accent; Set-IconTier Auto }
function Get-InterfaceMode { $v=Get-UserSetting -Name 'interface_mode'; if (@('Dashboard','Palette','Assistant') -notcontains $v) { return 'Dashboard' }; return $v }
function Set-InterfaceMode { param([string]$Mode) [void](Set-UserSetting -Name 'interface_mode' -Value $Mode) }
function Get-WorkspacePath { $v=Get-UserSetting -Name 'workspace_path'; if ($v -and (Test-Path -LiteralPath $v -PathType Container)) { return $v }; return '' }
function Set-WorkspacePath { param([string]$Path) [void](Set-UserSetting -Name 'workspace_path' -Value ([IO.Path]::GetFullPath($Path))) }
function Test-DirectoryInput { param([string]$Text) if ([string]::IsNullOrWhiteSpace($Text)) { return 'Enter A Folder Path.' }; if (-not (Test-Path -LiteralPath $Text -PathType Container)) { return 'The Folder Does Not Exist.' }; return $null }

function Select-Workspace {
    $path=Read-ValidatedInput -Prompt 'Workspace Folder' -Help 'Choose An Existing Folder. Git Is Never Initialized Automatically.' -Example 'C:\Projects\Example' -Validate { param($v) Test-DirectoryInput $v }
    if ($null -eq $path) { return }
    Set-WorkspacePath $path
    $s=Get-GitWorkspaceState $path
    $message=if ($s.IsRepository) { 'Repository Root: ' + $s.Root } else { 'This Folder Is Not A Git Repository.' }
    Show-Notice -Title 'Workspace Selected' -Lines @($message) -Kind Info
}

function Initialize-Repository {
    $path=Get-WorkspacePath
    if (-not $path) { Select-Workspace; $path=Get-WorkspacePath }
    if (-not $path) { return }
    if ((Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Already Exists' -Lines @('No Initialization Was Performed.') -Kind Info; return }
    if (-not (Show-Confirm -Title 'Initialize Repository?' -Message ('Git Init Will Create Metadata In: ' + $path) -YesLabel 'Initialize Repository' -NoLabel 'Cancel')) { return }
    $r=Invoke-Git -Arguments @('init') -WorkingDirectory $path
    if ($r.ExitCode -eq 0 -and (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Initialized' -Lines @('Git Created Repository Metadata.') -Kind Success } else { Show-Notice -Title 'Initialization Failed' -Lines @($r.StdErr) -Kind Error }
}

function Show-WorkspaceDashboard {
    $path=Get-WorkspacePath
    if (-not $path) { Show-Notice -Title 'No Workspace Selected' -Lines @('Select A Folder First.') -Kind Info; return }
    $snapshot=Get-ProjectManagementSnapshot $path
    if (-not $snapshot.IsRepository) { Show-Notice -Title 'Not A Repository' -Lines @('Initialize This Folder Only If You Intend To Create Git Metadata.') -Kind Warning; return }
    $branch=$snapshot.Branch
    if (-not $branch) { $branch='Detached Or Unborn' }
    $upstream=$snapshot.Upstream
    if (-not $upstream) { $upstream='Not Configured' }
    $operation=$snapshot.Operation
    if (-not $operation) { $operation='None' }
    $remoteText=@()
    foreach($remote in @($snapshot.Remotes)) { $remoteText += $remote.Name + ': ' + $remote.Url }
    if(-not $remoteText.Count) { $remoteText=@('None') }
    Show-Notice -Title 'Workspace Dashboard' -Lines @(
        'Path: ' + (Format-ProjectDisplayText -Text $snapshot.Root -Maximum 150),
        'Branch: ' + $branch + '   Upstream: ' + $upstream,
        'HEAD: ' + $snapshot.Head + '   Ahead: ' + $snapshot.Ahead + '   Behind: ' + $snapshot.Behind,
        'Staged: ' + $snapshot.Staged + '   Unstaged: ' + $snapshot.Unstaged + '   Untracked: ' + $snapshot.Untracked,
        'Operation In Progress: ' + $operation,
        'Remotes: ' + ($remoteText -join ', '),
        'Last Commit: ' + (Format-ProjectDisplayText -Text $snapshot.LastCommit -Maximum 160)
    ) -Kind Info
}
function Get-Inventory { param([string]$Root) $items=Get-GitCommandInventory; $data=Join-Path $Root 'data'; if (-not (Test-Path -LiteralPath $data)) { [void](New-Item -ItemType Directory -Path $data -Force) }; Export-GitCommandCatalog -Inventory $items -Path (Join-Path $data 'commands.json'); return $items }

function Invoke-CommandRecord {
    param([object]$Record)
    $path=Get-WorkspacePath
    $text=Read-ValidatedInput -Prompt ('Arguments For Git ' + $Record.Name) -Help 'Optional Space-Separated Arguments.' -Example '--help' -Validate { param($v) if ($v -match "[\r\n]") { 'Use One Line.' } else { $null } }
    if ($null -eq $text) { return }
    $args=@($Record.Name); if ($text) { $args += @($text -split '\s+') }
    $risk=Get-GitRiskTier -Command $Record.Name -Arguments $args
    $preview=Format-GitCommand $args
    if ($risk -ne 'ReadOnly') { if (-not (Show-Confirm -Title 'Review Git Operation' -Message ($preview + '. ' + (Get-RiskExplanation $risk)) -YesLabel 'Run This Operation' -NoLabel 'Cancel')) { return } }
    $r=Invoke-Git -Arguments $args -WorkingDirectory $path
    $output=($r.StdOut + $r.StdErr).Trim(); if ($output.Length -gt 700) { $output=$output.Substring(0,700) + '...' }
    if ($r.ExitCode -eq 0) { Show-Notice -Title 'Git Command Completed' -Lines @($preview,$output) -Kind Success } else { Show-Notice -Title 'Git Command Failed' -Lines @($preview,$output) -Kind Error }
}

function Show-CommandExplorer {
    param([string]$Root,[bool]$Palette=$false)
    $inventory=Get-Inventory $Root
    if (-not $inventory.Count) { Show-Notice -Title 'Command Discovery Failed' -Lines @('Git Help Could Not Be Read.') -Kind Error; return }
    $items=@()
    foreach ($record in $inventory) { $items += New-MenuItem -Label ('git ' + $record.Name) -Desc ($record.Category + '. ' + $record.Summary) -Value $record.Name -Icon 'Command' }
    $items += New-MenuItem -Label 'Project Management' -Desc 'Manage Local Projects, Remotes, Branches, And GitHub Pages.' -Value '__projects' -Icon 'Project'
    $items += New-MenuItem -Label 'Return To Task Dashboard' -Desc 'Open Workspace Categories And Interface Settings.' -Value '__dashboard' -Icon 'Dashboard'
    $items += New-MenuItem -Label 'Interface Mode Settings' -Desc 'Change The Preferred Interface Immediately.' -Value '__settings' -Icon 'Settings'
    $navigation='Arrows'
    $preset='task-dashboard'
    $title='Command Explorer'
    if ($Palette) { $navigation='Search'; $preset='command-palette'; $title='Command Palette' }
    $choice=Show-Menu -Title $title -Description 'Commands Are Discovered From The Installed Git Version.' -Items $items -Navigation $navigation -Preset $preset
    if ($choice -eq '__settings') { $mode=Show-InterfaceSettings; if ($mode) { return ('__interface:' + $mode) }; return }
    if ($choice -eq '__projects') { return (Show-ProjectManagement -Root $Root) }
    if ($choice -eq '__dashboard') { return '__interface:Dashboard' }
    if ($choice) { $selected=@($inventory | Where-Object { $_.Name -eq $choice }); if ($selected.Count) { Invoke-CommandRecord -Record $selected[0] } }
}
function Show-CategoryDashboard {
    param([string]$Root)
    $inventory=Get-Inventory $Root
    if (-not $inventory.Count) { Show-Notice -Title 'Command Discovery Failed' -Lines @('Git Help Could Not Be Read.') -Kind Error; return }
    $categories=@($inventory | ForEach-Object { $_.Category } | Sort-Object -Unique)
    $items=@()
    foreach ($category in $categories) { $count=@($inventory | Where-Object { $_.Category -eq $category }).Count; $items += New-MenuItem -Label $category -Desc ($count.ToString() + ' Discovered Git Commands. Select To Browse Commands In This Category.') -Value $category -Icon 'Item' }
    $items += New-MenuItem -Label 'Workspace Overview' -Desc 'Review Repository State, Upstream, And Change Counts.' -Value '__workspace' -Icon 'Info'
    $items += New-MenuItem -Label 'Project Management' -Desc 'Manage Local Projects, GitHub Connections, And Repository Pages.' -Value '__projects' -Icon 'Project'
    $items += New-MenuItem -Label 'Interface Mode Settings' -Desc 'Switch Dashboard, Command Palette, Or Assistant Console.' -Value '__settings' -Icon 'Settings'
    $items += New-MenuItem -Label 'Return To Main Menu' -Desc 'Open Settings Or Switch Interface Modes.' -Value '__back' -Icon 'Exit'
    $category=Show-Menu -Title 'Task Dashboard' -Description 'Browse Git Commands By Category Or Review The Current Workspace.' -Items $items -Navigation Arrows -Preset 'task-dashboard'
    if ($category -eq '__workspace') { Show-WorkspaceDashboard; return }
    if ($category -eq '__projects') { return (Show-ProjectManagement -Root $Root) }
    if ($category -eq '__settings') { $mode=Show-InterfaceSettings; if ($mode) { return ('__interface:' + $mode) }; return }
    if ($category -eq '__back' -or -not $category) { return '__interface:Dashboard' }
    $records=@($inventory | Where-Object { $_.Category -eq $category })
    $commands=@()
    foreach ($record in $records) { $commands += New-MenuItem -Label ('git ' + $record.Name) -Desc ($record.SupportLevel + '. ' + $record.Summary) -Value $record.Name -Icon 'Command' }
    $command=Show-Menu -Title $category -Description 'Select A Command To Review Its Arguments And Risk.' -Items $commands -Navigation Arrows -Preset 'file-explorer'
    if ($command) { $record=@($records | Where-Object { $_.Name -eq $command })[0]; Invoke-CommandRecord -Record $record }
}
function Invoke-StageWorkflow {
    $path=Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Staging Files.') -Kind Warning; return }
    $entries=@(Get-GitStatusEntries $path)
    if (-not $entries.Count) { Show-Notice -Title 'No Changes Found' -Lines @('The Working Tree Has No Changes To Stage.') -Kind Info; return }
    $items=@()
    foreach ($entry in $entries) { $code=$entry.Substring(0,2); $name=$entry.Substring(3); $safeName=Format-ProjectDisplayText -Text $name -Maximum 100; $label=$safeName; if ($code -eq ([string][char]63 + [string][char]63)) { $label='Untracked: ' + $safeName } else { $label=$code + ' ' + $safeName }; $items += New-MenuItem -Label $label -Desc 'Select This File For The Staging Area.' -Value $name -Icon 'Item' }
    $items += New-MenuItem -Label 'Cancel' -Desc 'Do Not Stage Any Files.' -Value '__cancel' -Icon 'Exit'
    $selected=Show-Menu -Title 'Select Files To Stage' -Description 'Choose One File At A Time.' -Items $items -Navigation Arrows -Preset 'file-explorer'
    if (-not $selected -or $selected -eq '__cancel') { return }
    $args=@('add','--',$selected)
    if (-not (Show-Confirm -Title 'Stage Selected File?' -Message ((Format-GitCommand $args) + '. This Changes The Index, Not Commit History.'))) { return }
    $r=Invoke-Git -Arguments $args -WorkingDirectory $path
    if ($r.ExitCode -eq 0) { Show-Notice -Title 'File Staged' -Lines @('Selected Changes Are In The Staging Area.') -Kind Success } else { Show-Notice -Title 'Staging Failed' -Lines @($r.StdErr) -Kind Error }
}

function Invoke-CommitWorkflow {
    $path=Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Creating A Commit.') -Kind Warning; return }
    $state=Get-GitWorkspaceState $path
    if (-not ($state.Staged + $state.Unstaged + $state.Untracked)) { Show-Notice -Title 'Nothing To Commit' -Lines @('The Repository Has No Changes.') -Kind Info; return }
    $staged=@(Get-GitStagedFiles $path)
    if (-not $staged.Count) { if (-not (Show-Confirm -Title 'Stage Changes First?' -Message 'A Commit Uses Staged Changes. Choose A File To Stage; Nothing Is Staged Automatically.' -YesLabel 'Choose A File' -NoLabel 'Cancel')) { return }; Invoke-StageWorkflow; $staged=@(Get-GitStagedFiles $path); if (-not $staged.Count) { return } }
    $identity=Invoke-Git -Arguments @('var','GIT_AUTHOR_IDENT') -WorkingDirectory $path -TimeoutSec 10
    if ($identity.ExitCode -ne 0) { Show-Notice -Title 'Commit Identity Missing' -Lines @('Set Repository-Local user.name And user.email Before Committing.') -Kind Warning; return }
    $message=Read-ValidatedInput -Prompt 'Commit Message' -Help 'Describe The Snapshot This Commit Records.' -Example 'fix: correct login validation' -Validate { param($v) if ([string]::IsNullOrWhiteSpace($v)) { 'A Commit Message Is Required.' } else { $null } }
    if ($null -eq $message) { return }
    $stat=(Invoke-Git -Arguments @('diff','--cached','--stat') -WorkingDirectory $path).StdOut
    $args=@('commit','-m',$message); $preview=Format-GitCommand $args
    if (-not (Show-Confirm -Title 'Create Commit?' -Message ($stat + ' ' + $preview + '. This Commit Is Local; Push Is Separate.'))) { return }
    $before=(Invoke-Git -Arguments @('rev-parse','HEAD') -WorkingDirectory $path).StdOut.Trim()
    $r=Invoke-Git -Arguments $args -WorkingDirectory $path -TimeoutSec 120
    $after=(Invoke-Git -Arguments @('rev-parse','HEAD') -WorkingDirectory $path).StdOut.Trim()
    if ($r.ExitCode -eq 0 -and $after -and $after -ne $before) { Show-Notice -Title 'Commit Created' -Lines @('Commit: ' + $after,'Commit Is Local. Push Is Separate.') -Kind Success } else { Show-Notice -Title 'Commit Failed' -Lines @($r.StdErr) -Kind Error }
}

function Invoke-BranchWorkflow {
    $path=Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Managing Branches.') -Kind Warning; return }
    $name=Read-ValidatedInput -Prompt 'New Branch Name' -Help 'Enter A Branch Name That Git Accepts.' -Example 'feature/search' -Validate { param($v) if ([string]::IsNullOrWhiteSpace($v) -or $v.StartsWith('-')) { 'Enter A Valid Branch Name.' } else { $null } }
    if (-not $name) { return }
    if ((Invoke-Git -Arguments @('check-ref-format','--branch',$name) -WorkingDirectory $path).ExitCode -ne 0) { Show-Notice -Title 'Invalid Branch Name' -Lines @('Git Rejected This Branch Name.') -Kind Error; return }
    $args=@('switch','-c',$name)
    if (-not (Show-Confirm -Title 'Create And Switch Branch?' -Message (Format-GitCommand $args))) { return }
    $r=Invoke-Git -Arguments $args -WorkingDirectory $path
    if ($r.ExitCode -eq 0) { Show-Notice -Title 'Branch Created' -Lines @('Switched To ' + $name + '.') -Kind Success } else { Show-Notice -Title 'Branch Creation Failed' -Lines @($r.StdErr) -Kind Error }
}

function Invoke-RemoteWorkflow {
    $path=Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Adding A Remote.') -Kind Warning; return }
    $name=Read-ValidatedInput -Prompt 'Remote Name' -Help 'Choose A Short Name For The Remote Repository.' -Example 'origin' -Validate { param($v) if ([string]::IsNullOrWhiteSpace($v) -or $v.StartsWith('-') -or $v -match '\s') { 'Enter A Valid Remote Name.' } else { $null } }
    if (-not $name) { return }
    $url=Read-ValidatedInput -Prompt 'Remote URL' -Help 'Use An HTTPS Or SSH Repository URL. Avoid Embedded Credentials.' -Example 'https://github.com/account/project.git' -Validate { param($v) if ([string]::IsNullOrWhiteSpace($v) -or $v -match '[\r\n]') { 'Enter A Single-Line Remote URL.' } else { $null } }
    if (-not $url) { return }
    if (-not (Show-Confirm -Title 'Add Remote?' -Message ('git remote add ' + $name + ' [URL Hidden For Privacy].'))) { return }
    $r=Invoke-Git -Arguments @('remote','add',$name,$url) -WorkingDirectory $path
    if ($r.ExitCode -eq 0) { Show-Notice -Title 'Remote Added' -Lines @('Remote ' + $name + ' Was Added. URL Is Hidden.') -Kind Success } else { Show-Notice -Title 'Remote Not Added' -Lines @($r.StdErr) -Kind Error }
}

function Invoke-RemoteSyncWorkflow {
    param([ValidateSet('fetch','pull','push')][string]$Operation)
    $path = Get-WorkspacePath
    if (-not $path) { Show-Notice -Title 'No Workspace Selected' -Lines @('Select A Repository Before Synchronizing.') -Kind Warning; return }
    $snapshot = Get-ProjectManagementSnapshot $path
    if (-not $snapshot.IsRepository -or $snapshot.IsBare) { Show-Notice -Title 'Working Repository Required' -Lines @('Select A Non-Bare Git Repository Before Synchronizing.') -Kind Warning; return }
    if (-not $snapshot.Remotes.Count) { Show-Notice -Title 'Remote Required' -Lines @('Connect A Remote Before Fetch, Pull, Or Push.') -Kind Warning; return }
    if ($Operation -ne 'fetch' -and $snapshot.Operation) { Show-Notice -Title 'Git Operation In Progress' -Lines @('Finish Or Safely Resolve The Active ' + $snapshot.Operation + ' Operation Before Synchronizing.') -Kind Warning; return }
    $arguments = @()
    $title = ''
    $message = ''
    if ($Operation -eq 'fetch') {
        $arguments = @('fetch')
        $title = 'Fetch Remote Changes?'
        $message = 'Download Remote References. Working Files And Local Commits Will Not Change.'
    } elseif ($Operation -eq 'pull') {
        if (-not $snapshot.Upstream) { Show-Notice -Title 'Branch Upstream Required' -Lines @('Set An Upstream Or Connect A Branch Before Pulling.') -Kind Warning; return }
        if ($snapshot.Staged -or $snapshot.Unstaged -or $snapshot.Untracked) { Show-Notice -Title 'Review Local Changes First' -Lines @('Commit, Stage, Stash, Or Otherwise Resolve Local Changes Before Pulling.') -Kind Warning; return }
        $arguments = @('pull','--ff-only')
        $title = 'Update From Remote?'
        $message = 'Run git pull --ff-only From ' + $snapshot.Upstream + '. A Non-Fast-Forward Update Will Be Stopped.'
    } else {
        if (-not $snapshot.Branch) { Show-Notice -Title 'Branch Required' -Lines @('Create A Commit And Local Branch Before Pushing.') -Kind Warning; return }
        $hasUpstream = [bool]$snapshot.Upstream
        $remoteName = ''
        if ($hasUpstream) {
            $remoteName = $snapshot.Upstream.Split('/')[0]
        } else {
            $remote = Select-ProjectRemote -Path $snapshot.Root -Title 'Select Push Remote'
            if (-not $remote) { Show-Notice -Title 'No Push Remote Selected' -Lines @('Cancel Did Not Change The Repository.') -Kind Info; return }
            $remoteName = $remote.Name
        }
        try { $arguments = @(New-GitPushArguments -Remote $remoteName -Branch $snapshot.Branch -HasUpstream $hasUpstream) } catch { Show-Notice -Title 'Push Target Is Invalid' -Lines @('Review The Current Branch And Remote Configuration.') -Kind Error; return }
        $title = 'Push Local Commits?'
        $message = 'Push Branch ' + $snapshot.Branch + ' To ' + $remoteName + '. Force Push Is Never Added. Uncommitted Files Are Not Uploaded.'
        if (-not $hasUpstream) { $message += ' The First Push Will Set The Upstream.' }
    }
    if (-not (Show-Confirm -Title $title -Message $message -YesLabel 'Continue' -NoLabel 'Cancel' -Default $false)) { return }
    $result = Invoke-Git -Arguments $arguments -WorkingDirectory $snapshot.Root -TimeoutSec 120
    $output = ($result.StdOut + $result.StdErr).Trim()
    if ($result.ExitCode -eq 0) {
        if ($Operation -eq 'push') {
            $updated = Get-ProjectManagementSnapshot $snapshot.Root
            if ($updated.Upstream) { Show-Notice -Title 'Push Completed' -Lines @('Upstream: ' + $updated.Upstream,'Local Commits Were Sent Without Force.') -Kind Success }
            else { Show-Notice -Title 'Push Completed' -Lines @('Git Confirmed The Push. Review The Upstream Setting If Needed.') -Kind Success }
        } else { Show-Notice -Title 'Remote Operation Completed' -Lines @('Git ' + $Operation + ' Finished.',(Format-ProjectDisplayText -Text $output -Maximum 400)) -Kind Success }
    } else { Show-Notice -Title 'Remote Operation Failed' -Lines @('Git ' + $Operation + ' Failed. Review The Remote, Authentication, And Local Branch State.','Exit Code: ' + $result.ExitCode) -Kind Error }
}
function Invoke-UndoWorkflow {
    $path=Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Reviewing Recovery Options.') -Kind Warning; return }
    $items=@((New-MenuItem -Label 'Restore An Unstaged File' -Desc 'Discard Working Tree Changes For One Named File.' -Value 'restore' -Icon 'Warning'),(New-MenuItem -Label 'Revert A Commit' -Desc 'Create A New Commit That Reverses An Earlier Commit.' -Value 'revert' -Icon 'Item'),(New-MenuItem -Label 'Review Reflog' -Desc 'Inspect Recent HEAD Moves Without Changing Repository State.' -Value 'reflog' -Icon 'Info'),(New-MenuItem -Label 'Cancel' -Desc 'Return Without Changes.' -Value 'cancel' -Icon 'Exit'))
    $choice=Show-Menu -Title 'Undo And Recovery' -Description 'Review The Exact Target And Risk Before Any Change.' -Items $items -Navigation Arrows
    if ($choice -eq 'reflog') { Invoke-CommandRecord (New-GitCommandRecord 'reflog'); return }
    if ($choice -eq 'cancel' -or -not $choice) { return }
    $example='HEAD~1'; if ($choice -eq 'restore') { $example='src/file.ps1' }
    $target=Read-ValidatedInput -Prompt 'Commit Or File Target' -Help 'Enter A File Path For Restore Or A Commit ID For Revert.' -Example $example -Validate { param($v) if ([string]::IsNullOrWhiteSpace($v) -or $v.StartsWith('-')) { 'Enter A Valid Target.' } else { $null } }
    if (-not $target) { return }
    if ($choice -eq 'restore') { $args=@('restore','--worktree','--',$target); $title='Discard Working Tree Changes For This File?' } else { $args=@('revert','--no-edit',$target); $title='Create A New Revert Commit?' }
    if (-not (Show-Confirm -Title $title -Message ((Format-GitCommand $args) + '. Review The Exact Target Carefully.'))) { return }
    $r=Invoke-Git -Arguments $args -WorkingDirectory $path -TimeoutSec 120
    if ($r.ExitCode -eq 0) { Show-Notice -Title 'Recovery Action Completed' -Lines @('Git Completed The Requested Recovery Action.') -Kind Success } else { Show-Notice -Title 'Recovery Action Failed' -Lines @($r.StdErr) -Kind Error }
}

function Format-ProjectDisplayText {
    param([AllowEmptyString()][string]$Text, [int]$Maximum=100)
    $builder = New-Object System.Text.StringBuilder
    foreach ($character in $Text.ToCharArray()) {
        if ([char]::IsControl($character)) { [void]$builder.Append('?') } else { [void]$builder.Append($character) }
    }
    $safe = $builder.ToString()
    if ($safe.Length -gt $Maximum) { return $safe.Substring(0,$Maximum - 3) + '...' }
    return $safe
}

function Show-ProjectRepositoryStatus {
    $path = Get-WorkspacePath
    if (-not $path) { Show-Notice -Title 'No Workspace Selected' -Lines @('Select A Workspace Folder Before Reviewing Repository Status.') -Kind Warning; return }
    $snapshot = Get-ProjectManagementSnapshot $path
    if (-not $snapshot.IsRepository) { Show-Notice -Title 'Not A Git Repository' -Lines @('Choose Initialize Repository Only If You Intend To Create Git Metadata.') -Kind Warning; return }
    if ($snapshot.IsBare) { Show-Notice -Title 'Bare Repository' -Lines @('Path: ' + (Format-ProjectDisplayText $snapshot.Root),'A Bare Repository Has No Working Tree To Review.') -Kind Info; return }
    $branch = $snapshot.Branch
    if (-not $branch) { $branch = 'Detached Or Unborn' }
    $upstream = $snapshot.Upstream
    if (-not $upstream) { $upstream = 'Not Configured' }
    $remoteLines = @()
    foreach ($remote in @($snapshot.Remotes)) { $remoteLines += (Format-ProjectDisplayText -Text $remote.Name -Maximum 40) + ': ' + (Format-ProjectDisplayText -Text $remote.Url -Maximum 100) }
    if (-not $remoteLines.Count) { $remoteLines = @('Remotes: None') }
    $operation = $snapshot.Operation
    if (-not $operation) { $operation = 'None' }
    $last = $snapshot.LastCommit
    if (-not $last) { $last = 'No Commit Yet' }
    $lines = @(
        'Path: ' + (Format-ProjectDisplayText -Text $snapshot.Root -Maximum 150),
        'Branch: ' + (Format-ProjectDisplayText -Text $branch -Maximum 100),
        'HEAD: ' + (Format-ProjectDisplayText -Text $snapshot.Head -Maximum 40),
        'Upstream: ' + (Format-ProjectDisplayText -Text $upstream -Maximum 100),
        'Ahead: ' + $snapshot.Ahead + '   Behind: ' + $snapshot.Behind,
        'Staged: ' + $snapshot.Staged + '   Unstaged: ' + $snapshot.Unstaged + '   Untracked: ' + $snapshot.Untracked,
        'Operation In Progress: ' + $operation,
        'Last Commit: ' + (Format-ProjectDisplayText -Text $last -Maximum 160)
    )
    $lines += $remoteLines
    Show-Notice -Title 'Repository Status' -Lines $lines -Kind Info
}

function Show-ProjectChangeReview {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Reviewing Changes.') -Kind Warning; return }
    $snapshot = Get-ProjectManagementSnapshot $path
    $entries = @(Get-GitStatusEntries $snapshot.Root)
    if (-not $entries.Count) { Show-Notice -Title 'Working Tree Clean' -Lines @('There Are No Staged, Unstaged, Or Untracked Changes.') -Kind Success; return }
    $lines = @('Staged: ' + $snapshot.Staged + '   Unstaged: ' + $snapshot.Unstaged + '   Untracked: ' + $snapshot.Untracked)
    $limit = [math]::Min(12,$entries.Count)
    for ($index=0; $index -lt $limit; $index++) {
        $entry = $entries[$index]
        $code = $entry.Substring(0,2)
        $name = if ($entry.Length -gt 3) { $entry.Substring(3) } else { '' }
        $lines += (Format-ProjectDisplayText -Text $code -Maximum 10) + '  ' + (Format-ProjectDisplayText -Text $name -Maximum 100)
    }
    if ($entries.Count -gt $limit) { $lines += 'And ' + ($entries.Count - $limit) + ' More Changes.' }
    $lines += 'Use Stage File, Unstage File, And Create Commit To Control Each Step.'
    Show-Notice -Title 'Local Changes' -Lines $lines -Kind Info
}

function Invoke-StageAllWorkflow {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Staging Changes.') -Kind Warning; return }
    $state = Get-GitWorkspaceState $path
    $count = $state.Staged + $state.Unstaged + $state.Untracked
    if (-not $count) { Show-Notice -Title 'No Changes Found' -Lines @('The Working Tree Has No Changes To Stage.') -Kind Info; return }
    if (-not (Show-Confirm -Title 'Stage All Changes?' -Message ('Stage All ' + $count + ' Changes, Including Deletions, For Review. No Commit Will Be Created.') -YesLabel 'Stage All Changes' -NoLabel 'Cancel' -Default $false)) { return }
    $result = Invoke-Git -Arguments @('add','-A') -WorkingDirectory $path -TimeoutSec 60
    if ($result.ExitCode -eq 0) { Show-Notice -Title 'All Changes Staged' -Lines @('Review The Staged Changes Before Creating A Commit.') -Kind Success } else { Show-Notice -Title 'Staging Failed' -Lines @('Git Could Not Stage All Changes. Exit Code: ' + $result.ExitCode) -Kind Error }
}

function Invoke-UnstageWorkflow {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Unstaging Files.') -Kind Warning; return }
    $files = @(Get-GitStagedFiles $path)
    if (-not $files.Count) { Show-Notice -Title 'No Staged Changes' -Lines @('The Staging Area Is Empty.') -Kind Info; return }
    $items = @()
    foreach ($file in $files) { $items += New-MenuItem -Label (Format-ProjectDisplayText -Text $file) -Desc 'Remove This Path From Staging. Working Files Are Preserved.' -Value $file -Icon 'Unstage' }
    $items += New-MenuItem -Label 'Cancel' -Desc 'Keep The Staging Area Unchanged.' -Value '__cancel' -Icon 'Exit'
    $selected = Show-Menu -Title 'Select A File To Unstage' -Description 'Unstaging Does Not Discard Working File Content.' -Items $items -Navigation Arrows -Preset 'file-explorer'
    if (-not $selected -or $selected -eq '__cancel') { return }
    if (-not (Show-Confirm -Title 'Unstage Selected File?' -Message ('Remove ' + (Format-ProjectDisplayText -Text $selected) + ' From The Staging Area. Keep Its Working File.') -YesLabel 'Unstage File' -NoLabel 'Cancel')) { return }
    $result = Invoke-Git -Arguments @('restore','--staged','--',$selected) -WorkingDirectory $path -TimeoutSec 30
    if ($result.ExitCode -eq 0) { Show-Notice -Title 'File Unstaged' -Lines @('The Working File Was Preserved.') -Kind Success } else { Show-Notice -Title 'Unstage Failed' -Lines @('Git Could Not Unstage The Selected File. Exit Code: ' + $result.ExitCode) -Kind Error }
}

function Select-ProjectRemote {
    param([Parameter(Mandatory)][string]$Path, [string]$Title='Select A Remote')
    $remotes = @(Get-ProjectRemoteInventory $Path)
    if (-not $remotes.Count) { return $null }
    if ($remotes.Count -eq 1) { return $remotes[0] }
    $items = @()
    foreach ($remote in $remotes) { $items += New-MenuItem -Label $remote.Name -Desc (Format-ProjectDisplayText -Text $remote.Url -Maximum 120) -Value $remote.Name -Icon 'Remote' }
    $name = Show-Menu -Title $Title -Description 'Choose A Configured Remote.' -Items $items -Navigation Arrows -Preset 'file-explorer'
    if (-not $name) { return $null }
    $found = @($remotes | Where-Object { $_.Name -eq $name } | Select-Object -First 1)
    if ($found.Count) { return $found[0] }
    return $null
}

function Select-GitHubRemoteTarget {
    param([Parameter(Mandatory)][string]$Path)
    $remotes = @(Get-ProjectRemoteInventory $Path)
    $targets = @()
    foreach ($remote in $remotes) {
        $raw = Invoke-Git -Arguments @('remote','get-url',$remote.Name) -WorkingDirectory $Path -TimeoutSec 15
        if ($raw.ExitCode -ne 0) { continue }
        $parsed = Test-GitHubRepositoryUrl $raw.StdOut.Trim()
        if ($parsed.IsValid) { $targets += [pscustomobject]@{ Remote=$remote.Name; Repository=($parsed.Owner + '/' + $parsed.Repository); PageUrl=(Get-GitHubPageUrl $raw.StdOut.Trim()) } }
    }
    if (-not $targets.Count) { return $null }
    if ($targets.Count -eq 1) { return $targets[0] }
    $items = @()
    foreach ($target in $targets) { $items += New-MenuItem -Label $target.Repository -Desc ('Remote ' + $target.Remote + '. ' + $target.PageUrl) -Value $target.Remote -Icon 'GitHub' }
    $name = Show-Menu -Title 'Select A GitHub Repository' -Description 'Choose A GitHub Remote For This Action.' -Items $items -Navigation Arrows -Preset 'file-explorer'
    if (-not $name) { return $null }
    $found = @($targets | Where-Object { $_.Remote -eq $name } | Select-Object -First 1)
    if ($found.Count) { return $found[0] }
    return $null
}

function Invoke-ConnectGitHubWorkflow {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select Or Initialize A Local Repository Before Connecting GitHub.') -Kind Warning; return }
    $url = Read-ValidatedInput -Prompt 'GitHub Repository URL' -Help 'Enter An HTTPS Or SSH URL For A GitHub Repository. Do Not Include Credentials.' -Example 'https://github.com/Owner/Project.git' -Validate { param($value) $check = Test-GitHubRepositoryUrl $value; if ($check.IsValid) { $null } else { $check.Error } }
    if ($null -eq $url) { return }
    $parsed = Test-GitHubRepositoryUrl $url
    $name = Read-ValidatedInput -Prompt 'Remote Name' -Help 'Use A New Name. Existing Remotes Are Preserved.' -Example 'origin' -Default 'origin' -Validate { param($value) if (Test-GitRemoteName $value) { $null } else { 'Enter A Valid Remote Name.' } }
    if ($null -eq $name) { return }
    $existing = @(Get-ProjectRemoteInventory $path | Where-Object { $_.Name -eq $name })
    if ($existing.Count) { Show-Notice -Title 'Remote Name Already Exists' -Lines @('Choose A Different Name Or Use Change Remote URL.') -Kind Warning; return }
    $probe = Invoke-Git -Arguments @('ls-remote',$parsed.Url,'HEAD') -WorkingDirectory $path -TimeoutSec 30
    if (-not $probe.Started -or $probe.ExitCode -ne 0) { Show-Notice -Title 'GitHub Connection Check Failed' -Lines @('Git Could Not Reach The Repository. Check The URL And Git Authentication, Then Try Again.') -Kind Error; return }
    $message = 'Add Remote ' + $name + ' At ' + (Format-SafeRemoteUrl $parsed.Url) + '. Local History Will Be Preserved. No Files Will Be Uploaded.'
    if (-not (Show-Confirm -Title 'Connect GitHub Repository?' -Message $message -YesLabel 'Connect Repository' -NoLabel 'Cancel')) { return }
    $added = Invoke-Git -Arguments @('remote','add',$name,$parsed.Url) -WorkingDirectory $path -TimeoutSec 20
    if ($added.ExitCode -ne 0) { Show-Notice -Title 'Remote Was Not Added' -Lines @('Git Could Not Add The Selected Remote. Exit Code: ' + $added.ExitCode) -Kind Error; return }
    $verified = Test-GitRemoteConnection -Path $path -Remote $name
    if (-not $verified.Reachable) {
        $null = Invoke-Git -Arguments @('remote','remove',$name) -WorkingDirectory $path -TimeoutSec 15
        Show-Notice -Title 'Remote Verification Failed' -Lines @('The New Remote Was Removed Again. Check Its URL And Authentication Before Retrying.') -Kind Error
        return
    }
    Show-Notice -Title 'GitHub Repository Connected' -Lines @($parsed.Owner + '/' + $parsed.Repository,'Local Commits And Files Were Preserved. Push Is A Separate Action.') -Kind Success
}

function Invoke-ChangeRemoteUrlWorkflow {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Changing A Remote.') -Kind Warning; return }
    $remote = Select-ProjectRemote -Path $path -Title 'Select A Remote To Change'
    if (-not $remote) { Show-Notice -Title 'No Remote Selected' -Lines @('Add A Remote Before Changing Its URL.') -Kind Info; return }
    $url = Read-ValidatedInput -Prompt 'New GitHub Repository URL' -Help 'The Existing Remote Is Kept Until The New URL Passes A Connection Check.' -Example 'https://github.com/Owner/NewProject.git' -Validate { param($value) $check = Test-GitHubRepositoryUrl $value; if ($check.IsValid) { $null } else { $check.Error } }
    if ($null -eq $url) { return }
    $parsed = Test-GitHubRepositoryUrl $url
    $probe = Invoke-Git -Arguments @('ls-remote',$parsed.Url,'HEAD') -WorkingDirectory $path -TimeoutSec 30
    if (-not $probe.Started -or $probe.ExitCode -ne 0) { Show-Notice -Title 'New URL Could Not Be Verified' -Lines @('The Current Remote Was Preserved. Check The New URL And Authentication.') -Kind Error; return }
    $oldResult = Invoke-Git -Arguments @('remote','get-url',$remote.Name) -WorkingDirectory $path -TimeoutSec 15
    if ($oldResult.ExitCode -ne 0) { Show-Notice -Title 'Current URL Could Not Be Read' -Lines @('No Remote Setting Was Changed.') -Kind Error; return }
    $oldUrl = $oldResult.StdOut.Trim()
    $summary = $remote.Name + ': ' + (Format-SafeRemoteUrl $oldUrl) + ' -> ' + (Format-SafeRemoteUrl $parsed.Url) + '. Local History Will Not Change.'
    if (-not (Show-Confirm -Title 'Change Remote URL?' -Message $summary -YesLabel 'Change URL' -NoLabel 'Cancel' -Default $false)) { return }
    $changed = Invoke-Git -Arguments @('remote','set-url',$remote.Name,$parsed.Url) -WorkingDirectory $path -TimeoutSec 20
    if ($changed.ExitCode -ne 0) { Show-Notice -Title 'Remote URL Was Not Changed' -Lines @('Git Could Not Update The Remote. Exit Code: ' + $changed.ExitCode) -Kind Error; return }
    $verify = Test-GitRemoteConnection -Path $path -Remote $remote.Name
    if (-not $verify.Reachable) {
        $null = Invoke-Git -Arguments @('remote','set-url',$remote.Name,$oldUrl) -WorkingDirectory $path -TimeoutSec 20
        Show-Notice -Title 'Remote Change Was Rolled Back' -Lines @('The New URL Failed Verification, So The Previous URL Was Restored.') -Kind Error
        return
    }
    Show-Notice -Title 'Remote URL Updated' -Lines @('The New GitHub URL Is Reachable. Local History Was Preserved.') -Kind Success
}

function Invoke-RemoveRemoteWorkflow {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Removing A Remote.') -Kind Warning; return }
    $remote = Select-ProjectRemote -Path $path -Title 'Select A Remote To Remove'
    if (-not $remote) { Show-Notice -Title 'No Remote Selected' -Lines @('There Are No Configured Remotes.') -Kind Info; return }
    if (-not (Show-Confirm -Title 'Remove Remote Configuration?' -Message ('Remove ' + $remote.Name + ' (' + (Format-ProjectDisplayText -Text $remote.Url) + ') From This Local Repository. GitHub Data And Local History Are Not Deleted.') -YesLabel 'Remove Remote' -NoLabel 'Cancel' -Default $false)) { return }
    $result = Invoke-Git -Arguments @('remote','remove',$remote.Name) -WorkingDirectory $path -TimeoutSec 20
    $remaining = @(Get-ProjectRemoteInventory $path | Where-Object { $_.Name -eq $remote.Name })
    if ($result.ExitCode -eq 0 -and $remaining.Count -eq 0) { Show-Notice -Title 'Remote Removed' -Lines @('Only The Local Remote Configuration Was Removed.') -Kind Success } else { Show-Notice -Title 'Remote Removal Failed' -Lines @('Git Could Not Verify The Remote Removal.') -Kind Error }
}

function Show-RemoteVerification {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Verifying A Connection.') -Kind Warning; return }
    $remote = Select-ProjectRemote -Path $path -Title 'Select A Remote To Verify'
    if (-not $remote) { Show-Notice -Title 'No Remote Configured' -Lines @('Connect A Repository Before Running A Connection Check.') -Kind Info; return }
    $check = Test-GitRemoteConnection -Path $path -Remote $remote.Name
    if ($check.Reachable) { Show-Notice -Title 'Remote Connection Verified' -Lines @($remote.Name + ': ' + $check.Url,'Git Successfully Read The Remote HEAD Reference.') -Kind Success } else { Show-Notice -Title 'Remote Connection Failed' -Lines @($remote.Name + ': ' + $check.Error) -Kind Error }
}

function Invoke-CreateGitHubRepositoryWorkflow {
    $path = Get-WorkspacePath
    if (-not $path) { Show-Notice -Title 'No Workspace Selected' -Lines @('Select A Local Project Folder First.') -Kind Warning; return }
    $workspace = Get-GitWorkspaceState $path
    if (-not $workspace.IsRepository) {
        if (-not (Show-Confirm -Title 'Initialize This Local Project?' -Message ('Git Must Be Initialized Before A GitHub Repository Can Be Created In ' + (Format-ProjectDisplayText -Text $path -Maximum 120) + '. Existing Files Will Not Be Changed.') -YesLabel 'Initialize Repository' -NoLabel 'Cancel')) { return }
        $initialized = Invoke-Git -Arguments @('init') -WorkingDirectory $path -TimeoutSec 20
        if ($initialized.ExitCode -ne 0 -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Initialization Failed' -Lines @('Git Could Not Initialize This Folder. No GitHub Repository Was Created.') -Kind Error; return }
        $workspace = Get-GitWorkspaceState $path
    }
    if ($workspace.IsBare) { Show-Notice -Title 'Working Repository Required' -Lines @('A Bare Repository Does Not Have A Project Folder To Publish From.') -Kind Warning; return }
    $ghState = Get-GitHubCliState
    if (-not $ghState.Available) { Show-Notice -Title 'GitHub CLI Is Not Installed' -Lines @('Install GitHub CLI And Run gh auth login, Then Retry.','https://cli.github.com/') -Kind Warning; return }
    if (-not $ghState.Authenticated) { Show-Notice -Title 'GitHub Sign-In Is Required' -Lines @('Run gh auth login In A Terminal, Then Return To This Screen.') -Kind Warning; return }
    $name = Read-ValidatedInput -Prompt 'New GitHub Repository Name' -Help 'Enter A Repository Name Or Owner/Repository. The Default Visibility Is Private.' -Example 'Git-Command-Manager' -Validate { param($value) try { $null = New-GitHubRepositoryArguments -Name $value -Path 'C:\Project'; $null } catch { 'Enter A Valid Repository Name.' } }
    if ($null -eq $name) { return }
    $remoteNames = @(Get-ProjectRemoteInventory $path | ForEach-Object { $_.Name })
    $remoteName = 'origin'
    if ($remoteNames -contains $remoteName) {
        $remoteName = 'github'
        $suffix = 2
        while ($remoteNames -contains $remoteName) { $remoteName = 'github-' + $suffix; $suffix++ }
    }
    $visibilityItems = @((New-MenuItem -Label 'Private' -Desc 'Only People With Access Can View This Repository.' -Value 'private' -Icon 'Lock'),(New-MenuItem -Label 'Public' -Desc 'Anyone Can View The Repository And Its Complete History.' -Value 'public' -Icon 'Warning'))
    $visibility = Show-Menu -Title 'Choose GitHub Visibility' -Description 'Private Is The Recommended Default.' -Items $visibilityItems -Navigation Arrows -Preset 'assistant-console'
    if (-not $visibility) { return }
    if ($visibility -eq 'public') {
        if (-not (Show-Confirm -Title 'Create A Public Repository?' -Message 'Anyone Can View The Repository. This Cannot Hide Existing Commits Or Files.' -YesLabel 'Review Public Creation' -NoLabel 'Cancel' -Default $false)) { return }
        $typed = Read-ValidatedInput -Prompt 'Confirm Public Repository' -Help 'Type Make Public To Continue.' -Example 'Make Public' -Validate { param($value) if ($value -ceq 'Make Public') { $null } else { 'Type Make Public Exactly To Continue.' } }
        if ($null -eq $typed) { return }
    }
    $arguments = @(New-GitHubRepositoryArguments -Name $name -Path $workspace.Root -RemoteName $remoteName -Visibility $visibility)
    $visibilityText = if ($visibility -eq 'private') { 'Private' } else { 'Public' }
    $preview = 'gh ' + (ConvertTo-ProcessArgumentString -Arguments $arguments)
    if (-not (Show-Confirm -Title 'Create GitHub Repository?' -Message ($visibilityText + ' Repository. Command Preview: ' + $preview + '. This Creates The GitHub Page And Adds A Local Remote. It Does Not Push Files.') -YesLabel 'Create Repository' -NoLabel 'Cancel' -Default $false)) { return }
    $created = Invoke-GitHubCli -Arguments $arguments -WorkingDirectory $workspace.Root -TimeoutSec 90
    if (-not $created.Started -or $created.ExitCode -ne 0) { Show-Notice -Title 'GitHub Repository Was Not Verified' -Lines @('GitHub CLI Did Not Confirm Repository Creation. Exit Code: ' + $created.ExitCode) -Kind Error; return }
    $remoteUrl = Invoke-Git -Arguments @('remote','get-url',$remoteName) -WorkingDirectory $workspace.Root -TimeoutSec 15
    if ($remoteUrl.ExitCode -ne 0) { Show-Notice -Title 'GitHub Repository Created' -Lines @('GitHub CLI Created The Repository, But The Local Remote Could Not Be Verified.','Review The GitHub Page Before Continuing.') -Kind Warning; return }
    $page = Get-GitHubPageUrl $remoteUrl.StdOut.Trim()
    if (-not $page) { Show-Notice -Title 'GitHub Repository Created' -Lines @('The Local Remote Was Added, But Its URL Is Not A Standard GitHub URL. Review The Connection.') -Kind Warning; return }
    Show-Notice -Title 'GitHub Repository Created' -Lines @($page,'The Local Remote Was Verified. Push Is A Separate, Explicit Step.') -Kind Success
}

function Show-GitHubAuthenticationStatus {
    $state = Get-GitHubCliState
    if (-not $state.Available) { Show-Notice -Title 'GitHub CLI Is Not Installed' -Lines @('Remote Git Operations Can Still Use Git Credential Manager.','GitHub Page Editing And Repository Creation Require GitHub CLI.','https://cli.github.com/') -Kind Warning; return }
    if ($state.Authenticated) { Show-Notice -Title 'GitHub CLI Is Authenticated' -Lines @((Format-ProjectDisplayText -Text $state.Version -Maximum 100),'No Credential Or Token Was Displayed.') -Kind Success }
    else { Show-Notice -Title 'GitHub Sign-In Is Required' -Lines @('Run gh auth login In A Terminal, Then Return To This Screen.','Git Remote Credentials Are Managed Separately By Git.') -Kind Warning }
}

function Invoke-GitHubPageEditWorkflow {
    param([Parameter(Mandatory)][string]$Action)
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository With A GitHub Remote First.') -Kind Warning; return }
    $target = Select-GitHubRemoteTarget -Path $path
    if (-not $target) { Show-Notice -Title 'GitHub Remote Required' -Lines @('Connect An HTTPS Or SSH GitHub Remote Before Editing Its Page.') -Kind Warning; return }
    $ghState = Get-GitHubCliState
    if (-not $ghState.Available) { Show-Notice -Title 'GitHub CLI Is Not Installed' -Lines @('Install GitHub CLI And Run gh auth login, Then Retry.','https://cli.github.com/') -Kind Warning; return }
    if (-not $ghState.Authenticated) { Show-Notice -Title 'GitHub Sign-In Is Required' -Lines @('Run gh auth login In A Terminal, Then Return To This Screen.') -Kind Warning; return }
    $metadata = @{ Repository=$target.Repository }
    $summary = ''
    switch ($Action) {
        'description' {
            $value = Read-ValidatedInput -Prompt 'Repository Description' -Help 'This Text Appears On The GitHub Page. Use One Line Of 350 Characters Or Fewer.' -Example 'A Safe PowerShell Git Management App.' -Validate { param($text) if ($text.Length -le 350 -and $text -notmatch '[\r\n]') { $null } else { 'Use One Line Of 350 Characters Or Fewer.' } }
            if ($null -eq $value) { return }
            $metadata.Description = $value
            $summary = 'Set The GitHub Repository Description.'
        }
        'homepage' {
            $value = Read-ValidatedInput -Prompt 'Project Homepage URL' -Help 'Enter A Public HTTPS URL. Embedded Credentials Are Not Allowed.' -Example 'https://example.com/project' -Validate { param($text) try { $null = New-GitHubMetadataArguments -Repository 'Owner/Project' -Homepage $text; $null } catch { 'Enter A Valid HTTPS URL.' } }
            if ($null -eq $value) { return }
            $metadata.Homepage = $value
            $summary = 'Set The GitHub Repository Homepage.'
        }
        'add-topic' {
            $value = Read-ValidatedInput -Prompt 'Topic To Add' -Help 'Use Lowercase Letters, Numbers, And Hyphens.' -Example 'powershell' -Validate { param($text) try { $null = New-GitHubMetadataArguments -Repository 'Owner/Project' -AddTopics @($text); $null } catch { 'Use A Valid Lowercase Topic.' } }
            if ($null -eq $value) { return }
            $metadata.AddTopics = @($value)
            $summary = 'Add Topic ' + $value + ' To The Repository Page.'
        }
        'remove-topic' {
            $value = Read-ValidatedInput -Prompt 'Topic To Remove' -Help 'Enter An Existing Lowercase Topic Name.' -Example 'powershell' -Validate { param($text) try { $null = New-GitHubMetadataArguments -Repository 'Owner/Project' -RemoveTopics @($text); $null } catch { 'Use A Valid Lowercase Topic.' } }
            if ($null -eq $value) { return }
            $metadata.RemoveTopics = @($value)
            $summary = 'Remove Topic ' + $value + ' From The Repository Page.'
        }
        'visibility' {
            $visibility = Show-Menu -Title 'Repository Visibility' -Description 'Changing Visibility Affects Who Can Access The Full Repository History.' -Items @((New-MenuItem -Label 'Private' -Desc 'Restrict Access To People With Permission.' -Value 'private' -Icon 'Lock'),(New-MenuItem -Label 'Public' -Desc 'Allow Anyone To View The Repository And Its History.' -Value 'public' -Icon 'Warning')) -Navigation Arrows -Preset 'assistant-console'
            if (-not $visibility) { return }
            if ($visibility -eq 'public') {
                if (-not (Show-Confirm -Title 'Make Repository Public?' -Message 'Anyone Will Be Able To View The Repository And All Existing History.' -YesLabel 'Review Visibility Change' -NoLabel 'Cancel' -Default $false)) { return }
                $typed = Read-ValidatedInput -Prompt 'Confirm Repository Visibility' -Help 'Type Make Public To Continue.' -Example 'Make Public' -Validate { param($text) if ($text -ceq 'Make Public') { $null } else { 'Type Make Public Exactly To Continue.' } }
                if ($null -eq $typed) { return }
            }
            $metadata.Visibility = $visibility
            $summary = 'Change Repository Visibility To ' + $visibility + '.'
        }
        default { return }
    }
    try { $arguments = @(New-GitHubMetadataArguments @metadata) } catch { Show-Notice -Title 'Repository Page Change Is Invalid' -Lines @('Review The Input And Try Again.') -Kind Error; return }
    $preview = 'gh ' + (ConvertTo-ProcessArgumentString -Arguments $arguments)
    if (-not (Show-Confirm -Title 'Update GitHub Repository Page?' -Message ($target.Repository + '. Command Preview: ' + $preview + '. ' + $summary + ' This Does Not Change Local Files Or Git History.') -YesLabel 'Update GitHub Page' -NoLabel 'Cancel' -Default $false)) { return }
    $result = Invoke-GitHubCli -Arguments $arguments -WorkingDirectory $path -TimeoutSec 60
    if ($result.Started -and $result.ExitCode -eq 0) { Show-Notice -Title 'GitHub Repository Page Updated' -Lines @($target.PageUrl,$summary) -Kind Success } else { Show-Notice -Title 'GitHub Page Update Failed' -Lines @('GitHub CLI Could Not Confirm The Change. Check Repository Access And Try Again.') -Kind Error }
}

function Show-GitHubPageManagement {
    $items = @(
        (New-MenuItem -Label 'GitHub Authentication Status' -Desc 'Check Whether GitHub CLI Is Installed And Signed In.' -Value 'auth' -Icon 'Lock'),
        (New-MenuItem -Label 'Create GitHub Repository' -Desc 'Create A Private Repository By Default And Connect A Local Remote. No Automatic Push.' -Value 'create' -Icon 'GitHub'),
        (New-MenuItem -Label 'Edit Repository Description' -Desc 'Update The Short Description Shown On The GitHub Page.' -Value 'description' -Icon 'Page'),
        (New-MenuItem -Label 'Edit Repository Homepage' -Desc 'Set A Verified HTTPS Homepage Link.' -Value 'homepage' -Icon 'Page'),
        (New-MenuItem -Label 'Add Repository Topic' -Desc 'Add A Searchable Topic To The GitHub Page.' -Value 'add-topic' -Icon 'Item'),
        (New-MenuItem -Label 'Remove Repository Topic' -Desc 'Remove A Topic From The GitHub Page.' -Value 'remove-topic' -Icon 'Item'),
        (New-MenuItem -Label 'Change Repository Visibility' -Desc 'Review The Access Impact Before Changing Private Or Public Visibility.' -Value 'visibility' -Icon 'Warning'),
        (New-MenuItem -Label 'Show GitHub Page Address' -Desc 'Display The Verified Page URL For A Configured GitHub Remote.' -Value 'page' -Icon 'Page')
    )
    $choice = Show-ProjectActionMenu -Title 'GitHub Page Management' -Description 'GitHub CLI Is Used Only For GitHub Account And Page Operations.' -Items $items
    if ($choice -eq '__back' -or -not $choice) { return }
    if ($choice -like '__interface:*') { return $choice }
    if ($choice -eq 'auth') { Show-GitHubAuthenticationStatus; return }
    if ($choice -eq 'create') { Invoke-CreateGitHubRepositoryWorkflow; return }
    if ($choice -eq 'page') {
        $path = Get-WorkspacePath
        $target = if ($path) { Select-GitHubRemoteTarget -Path $path } else { $null }
        if ($target) { Show-Notice -Title 'GitHub Project Page' -Lines @($target.PageUrl) -Kind Info } else { Show-Notice -Title 'GitHub Page Not Found' -Lines @('Add A Standard GitHub HTTPS Or SSH Remote First.') -Kind Warning }
        return
    }
    Invoke-GitHubPageEditWorkflow -Action $choice
}

function Invoke-SetUpstreamWorkflow {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Setting An Upstream.') -Kind Warning; return }
    $snapshot = Get-ProjectManagementSnapshot $path
    if (-not $snapshot.Branch) { Show-Notice -Title 'Branch Required' -Lines @('Create Or Switch To A Local Branch Before Setting Its Upstream.') -Kind Warning; return }
    $branches = @(Get-GitBranchInventory -Path $snapshot.Root -Remote | Where-Object { -not $_.Name.EndsWith('/HEAD') })
    if (-not $branches.Count) { Show-Notice -Title 'Remote Branch Required' -Lines @('Fetch Remote References Before Setting An Upstream.') -Kind Info; return }
    $items = @()
    foreach ($branch in $branches) { $items += New-MenuItem -Label $branch.Name -Desc ('Remote Commit: ' + $branch.Commit) -Value $branch.Name -Icon 'Branch' }
    $selected = Show-Menu -Title 'Select Branch Upstream' -Description ('Set The Upstream For Local Branch ' + $snapshot.Branch + '.') -Items $items -Navigation Arrows -Preset 'file-explorer'
    if (-not $selected) { return }
    if (-not (Show-Confirm -Title 'Set Branch Upstream?' -Message ($snapshot.Branch + ' Will Track ' + $selected + '. No Commits Or Files Will Change.') -YesLabel 'Set Upstream' -NoLabel 'Cancel')) { return }
    $result = Invoke-Git -Arguments @('branch','--set-upstream-to',$selected) -WorkingDirectory $snapshot.Root -TimeoutSec 20
    if ($result.ExitCode -eq 0) { Show-Notice -Title 'Branch Upstream Set' -Lines @($snapshot.Branch + ' Now Tracks ' + $selected + '.') -Kind Success } else { Show-Notice -Title 'Upstream Was Not Changed' -Lines @('Git Could Not Set The Selected Upstream.') -Kind Error }
}

function Invoke-SwitchBranchWorkflow {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Switching Branches.') -Kind Warning; return }
    $snapshot = Get-ProjectManagementSnapshot $path
    $branches = @(Get-GitBranchInventory -Path $snapshot.Root)
    if (-not $branches.Count) { Show-Notice -Title 'No Local Branches' -Lines @('Create A Commit And Branch Before Switching.') -Kind Info; return }
    $items = @()
    foreach ($branch in $branches) { $description = if ($branch.Upstream) { 'Tracks ' + $branch.Upstream } else { 'No Upstream Configured.' }; $items += New-MenuItem -Label $branch.Name -Desc $description -Value $branch.Name -Icon 'Branch' }
    $selected = Show-Menu -Title 'Switch Local Branch' -Description 'Git Will Refuse To Overwrite Conflicting Local Changes.' -Items $items -Navigation Arrows -Preset 'file-explorer'
    if (-not $selected -or $selected -eq $snapshot.Branch) { return }
    if (-not (Show-Confirm -Title 'Switch Branch?' -Message ('Switch To ' + $selected + '. Git Will Preserve Compatible Working Changes.') -YesLabel 'Switch Branch' -NoLabel 'Cancel')) { return }
    $result = Invoke-Git -Arguments @('switch',$selected) -WorkingDirectory $snapshot.Root -TimeoutSec 30
    if ($result.ExitCode -eq 0) { Show-Notice -Title 'Branch Switched' -Lines @('Current Branch: ' + $selected) -Kind Success } else { Show-Notice -Title 'Branch Was Not Switched' -Lines @('Git Blocked The Switch. Review Local Changes And Retry.') -Kind Warning }
}

function Invoke-RenameBranchWorkflow {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Renaming A Branch.') -Kind Warning; return }
    $branches = @(Get-GitBranchInventory -Path $path)
    if (-not $branches.Count) { Show-Notice -Title 'No Local Branches' -Lines @('There Are No Local Branches To Rename.') -Kind Info; return }
    $items = @()
    foreach ($branch in $branches) { $items += New-MenuItem -Label $branch.Name -Desc 'Rename This Local Branch Without Rewriting Its Commits.' -Value $branch.Name -Icon 'Branch' }
    $oldName = Show-Menu -Title 'Select A Local Branch' -Description 'Remote Branches Are Not Renamed.' -Items $items -Navigation Arrows -Preset 'file-explorer'
    if (-not $oldName) { return }
    $newName = Read-ValidatedInput -Prompt 'New Branch Name' -Help 'Use A Git-Compatible Branch Name.' -Example 'feature/project-management' -Validate { param($value) if ((Invoke-Git -Arguments @('check-ref-format','--branch',$value) -WorkingDirectory $path -TimeoutSec 10).ExitCode -eq 0) { $null } else { 'Git Rejected This Branch Name.' } }
    if (-not $newName) { return }
    if (-not (Show-Confirm -Title 'Rename Local Branch?' -Message ($oldName + ' -> ' + $newName + '. Commits And Files Will Not Be Rewritten.') -YesLabel 'Rename Branch' -NoLabel 'Cancel')) { return }
    $result = Invoke-Git -Arguments @('branch','--move',$oldName,$newName) -WorkingDirectory $path -TimeoutSec 20
    if ($result.ExitCode -eq 0) { Show-Notice -Title 'Branch Renamed' -Lines @($oldName + ' -> ' + $newName) -Kind Success } else { Show-Notice -Title 'Branch Was Not Renamed' -Lines @('Git Could Not Rename The Selected Branch.') -Kind Error }
}

function Invoke-DeleteBranchWorkflow {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Deleting A Branch.') -Kind Warning; return }
    $snapshot = Get-ProjectManagementSnapshot $path
    $branches = @(Get-GitBranchInventory -Path $snapshot.Root | Where-Object { $_.Name -ne $snapshot.Branch })
    if (-not $branches.Count) { Show-Notice -Title 'No Eligible Branches' -Lines @('The Current Branch Cannot Be Deleted. Create Or Switch Branches First.') -Kind Info; return }
    $items = @()
    foreach ($branch in $branches) { $items += New-MenuItem -Label $branch.Name -Desc 'Git Will Refuse To Delete Unmerged Commits.' -Value $branch.Name -Icon 'Warning' }
    $selected = Show-Menu -Title 'Select A Local Branch To Delete' -Description 'Only The Safe git branch -d Operation Is Available.' -Items $items -Navigation Arrows -Preset 'file-explorer'
    if (-not $selected) { return }
    if (-not (Show-Confirm -Title 'Delete Local Branch?' -Message ('Delete ' + $selected + '. Git Will Keep The Branch If It Contains Unmerged Commits.') -YesLabel 'Delete Branch' -NoLabel 'Cancel' -Default $false)) { return }
    $result = Invoke-Git -Arguments @('branch','-d',$selected) -WorkingDirectory $snapshot.Root -TimeoutSec 30
    if ($result.ExitCode -eq 0) { Show-Notice -Title 'Branch Deleted' -Lines @($selected) -Kind Success } else { Show-Notice -Title 'Branch Was Not Deleted' -Lines @('Git Refused The Safe Delete. The Branch May Contain Unmerged Commits.') -Kind Warning }
}

function Show-BranchManagement {
    $items = @(
        (New-MenuItem -Label 'List Local And Remote Branches' -Desc 'Review Local Branches, Tracking Branches, And Commit IDs.' -Value 'list' -Icon 'Branch'),
        (New-MenuItem -Label 'Create A Branch' -Desc 'Validate A New Branch And Switch To It.' -Value 'create' -Icon 'Branch'),
        (New-MenuItem -Label 'Switch Local Branch' -Desc 'Change The Current Branch Without Overwriting Conflicting Changes.' -Value 'switch' -Icon 'Branch'),
        (New-MenuItem -Label 'Rename Local Branch' -Desc 'Rename A Branch Without Rewriting Its Commits.' -Value 'rename' -Icon 'Branch'),
        (New-MenuItem -Label 'Delete Local Branch' -Desc 'Use Git Safe Delete, Which Refuses Unmerged Branches.' -Value 'delete' -Icon 'Warning'),
        (New-MenuItem -Label 'Set Branch Upstream' -Desc 'Connect The Current Local Branch To A Fetched Remote Branch.' -Value 'upstream' -Icon 'Connect')
    )
    $choice = Show-ProjectActionMenu -Title 'Branch Management' -Description 'Branch Operations Are Local Unless An Upstream Is Explicitly Selected.' -Items $items
    if ($choice -eq '__back' -or -not $choice) { return }
    if ($choice -like '__interface:*') { return $choice }
    switch ($choice) {
        'list' {
            $path = Get-WorkspacePath
            if (-not $path) { Show-Notice -Title 'No Workspace Selected' -Lines @('Select A Repository First.') -Kind Warning; return }
            $snapshot = Get-ProjectManagementSnapshot $path
            $locals = @(Get-GitBranchInventory -Path $snapshot.Root)
            $remotes = @(Get-GitBranchInventory -Path $snapshot.Root -Remote)
            $lines = @()
            foreach ($branch in $locals) { $tracking = if ($branch.Upstream) { ' -> ' + $branch.Upstream } else { ' -> No Upstream' }; $lines += '* ' + $branch.Name + $tracking + ' (' + $branch.Commit + ')' }
            foreach ($branch in $remotes) { if (-not $branch.Name.EndsWith('/HEAD')) { $lines += '  ' + $branch.Name + ' (' + $branch.Commit + ')' } }
            if (-not $lines.Count) { $lines = @('No Branches Were Found.') }
            Show-Notice -Title 'Branches' -Lines $lines -Kind Info
        }
        'create' { Invoke-BranchWorkflow }
        'switch' { Invoke-SwitchBranchWorkflow }
        'rename' { Invoke-RenameBranchWorkflow }
        'delete' { Invoke-DeleteBranchWorkflow }
        'upstream' { Invoke-SetUpstreamWorkflow }
    }
}

function Show-RecentProjectHistory {
    $path = Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Reviewing History.') -Kind Warning; return }
    $result = Invoke-Git -Arguments @('log','-8','--date=short','--format=%h%x1f%ad%x1f%s') -WorkingDirectory $path -TimeoutSec 20
    if ($result.ExitCode -ne 0) { Show-Notice -Title 'History Is Not Available' -Lines @('Create The First Commit Or Review Git Repository State.') -Kind Info; return }
    $lines = @()
    foreach ($line in @($result.StdOut -split '[\r\n]+' | Where-Object { $_ })) {
        $parts = $line -split [char]31,3
        $lines += (Format-ProjectDisplayText -Text $parts[0] -Maximum 20) + '  ' + (Format-ProjectDisplayText -Text $parts[1] -Maximum 20) + '  ' + (Format-ProjectDisplayText -Text $parts[2] -Maximum 100)
    }
    Show-Notice -Title 'Recent Commit History' -Lines $lines -Kind Info
}

function Show-ProjectActionMenu {
    param([Parameter(Mandatory)][string]$Title, [string]$Description='', [object[]]$Items=@())
    $menuItems = @($Items)
    $menuItems += New-MenuItem -Label 'Return To Project Management' -Desc 'Go Back To Project Management Categories.' -Value '__back' -Icon 'Project'
    $menuItems += New-MenuItem -Label 'Return To Task Dashboard' -Desc 'Open The Main Dashboard And Workspace Categories.' -Value '__dashboard' -Icon 'Dashboard'
    $menuItems += New-MenuItem -Label 'Interface Mode Settings' -Desc 'Switch Dashboard, Command Palette, Or Assistant Console Immediately.' -Value '__settings' -Icon 'Settings'
    $choice = Show-Menu -Title $Title -Description $Description -Items $menuItems -Navigation Arrows -Preset 'task-dashboard'
    if ($choice -eq '__dashboard') { return '__interface:Dashboard' }
    if ($choice -eq '__settings') {
        $mode = Show-InterfaceSettings
        if ($mode) { return ('__interface:' + $mode) }
        return '__back'
    }
    return $choice
}

function Invoke-CreateProjectFolderWorkflow {
    $folder = Read-ValidatedInput -Prompt 'New Project Folder Path' -Help 'Choose A New Folder Whose Parent Already Exists. Existing Folders Are Not Used.' -Example 'C:\Projects\NewProject' -Validate { param($value) $check=Test-NewProjectDirectoryPath $value; if ($check.IsValid) { $null } else { $check.Error } }
    if ($null -eq $folder) { return }
    $check = Test-NewProjectDirectoryPath $folder
    if (-not $check.IsValid) { Show-Notice -Title 'Project Folder Is Not Available' -Lines @($check.Error) -Kind Warning; return }
    if (-not (Show-Confirm -Title 'Create New Project Folder?' -Message ($check.FullPath + '. This Creates One Empty Folder. No Git Repository Is Initialized Automatically.') -YesLabel 'Create Folder' -NoLabel 'Cancel' -Default $false)) { return }
    if (Test-Path -LiteralPath $check.FullPath) { Show-Notice -Title 'Project Folder Already Exists' -Lines @('Choose A New Destination. No Existing Folder Was Changed.') -Kind Warning; return }
    try {
        [void][IO.Directory]::CreateDirectory($check.FullPath)
        if (-not (Test-Path -LiteralPath $check.FullPath -PathType Container)) { throw 'Folder Verification Failed.' }
        Set-WorkspacePath $check.FullPath
        Show-Notice -Title 'Project Folder Created' -Lines @($check.FullPath,'Git Was Not Initialized. Use Initialize Repository Or Create GitHub Repository When Ready.') -Kind Success
    } catch { Show-Notice -Title 'Project Folder Was Not Created' -Lines @('Check The Parent Folder Permissions And Try Again.') -Kind Error }
}

function Invoke-CloneGitHubRepositoryWorkflow {
    $url = Read-ValidatedInput -Prompt 'GitHub Repository URL' -Help 'Enter An HTTPS Or SSH Repository URL Without Embedded Credentials.' -Example 'https://github.com/Owner/Project.git' -Validate { param($value) $check=Test-GitHubRepositoryUrl $value; if ($check.IsValid) { $null } else { $check.Error } }
    if ($null -eq $url) { return }
    $repository = Test-GitHubRepositoryUrl $url
    $destination = Read-ValidatedInput -Prompt 'Clone Destination Folder' -Help 'Choose A New Folder Whose Parent Already Exists.' -Example 'C:\Projects\Project' -Validate { param($value) $check=Test-NewProjectDirectoryPath $value; if ($check.IsValid) { $null } else { $check.Error } }
    if ($null -eq $destination) { return }
    $target = Test-NewProjectDirectoryPath $destination
    if (-not $target.IsValid) { Show-Notice -Title 'Clone Destination Is Not Available' -Lines @($target.Error) -Kind Warning; return }
    $probe = Invoke-Git -Arguments @('ls-remote',$repository.Url,'HEAD') -WorkingDirectory ([IO.Path]::GetDirectoryName($target.FullPath)) -TimeoutSec 30
    if (-not $probe.Started -or $probe.ExitCode -ne 0) { Show-Notice -Title 'GitHub Repository Is Not Reachable' -Lines @('Check The URL And Git Authentication. The Destination Folder Was Not Created.') -Kind Error; return }
    $arguments = @(New-GitCloneArguments -RepositoryUrl $repository.Url -Path $target.FullPath)
    $preview = 'git ' + (ConvertTo-ProcessArgumentString -Arguments $arguments)
    if (-not (Show-Confirm -Title 'Clone GitHub Repository?' -Message ($repository.Owner + '/' + $repository.Repository + '. Command Preview: ' + $preview + '. A New Local Folder And Git History Will Be Created.') -YesLabel 'Clone Repository' -NoLabel 'Cancel' -Default $false)) { return }
    $result = Invoke-Git -Arguments $arguments -WorkingDirectory ([IO.Path]::GetDirectoryName($target.FullPath)) -TimeoutSec 300
    $state = Get-GitWorkspaceState $target.FullPath
    if ($result.ExitCode -ne 0 -or -not $state.IsRepository) {
        $partial = Test-Path -LiteralPath $target.FullPath -PathType Container
        $line = 'Git Could Not Verify The Clone. Exit Code: ' + $result.ExitCode
        if ($partial) { $line += ' Any Partial Folder Was Left In Place For Review.' }
        Show-Notice -Title 'Clone Was Not Completed' -Lines @($line) -Kind Error
        return
    }
    $remote = Invoke-Git -Arguments @('remote','get-url','origin') -WorkingDirectory $target.FullPath -TimeoutSec 15
    $page = if ($remote.ExitCode -eq 0) { Get-GitHubPageUrl $remote.StdOut.Trim() } else { '' }
    Set-WorkspacePath $target.FullPath
    if ($page) { Show-Notice -Title 'GitHub Repository Cloned' -Lines @('Local Workspace: ' + $target.FullPath,'GitHub Page: ' + $page) -Kind Success }
    else { Show-Notice -Title 'Repository Cloned' -Lines @('Local Workspace: ' + $target.FullPath,'Git Cloned The Repository, But Its Remote Is Not A Standard GitHub URL.') -Kind Warning }
}

function Show-NewProjectSetup {
    $items = @(
        (New-MenuItem -Label 'Create Local Project Folder' -Desc 'Create A New Empty Folder Without Initializing Git Automatically.' -Value 'create' -Icon 'Folder'),
        (New-MenuItem -Label 'Clone GitHub Repository' -Desc 'Validate Access And Clone Into A New Folder With A Command Preview.' -Value 'clone' -Icon 'GitHub')
    )
    $choice = Show-ProjectActionMenu -Title 'New Project Setup' -Description 'Choose Whether To Start With An Empty Folder Or An Existing GitHub Repository.' -Items $items
    if ($choice -like '__interface:*') { return $choice }
    if ($choice -eq '__back' -or -not $choice) { return }
    if ($choice -eq 'create') { Invoke-CreateProjectFolderWorkflow } else { Invoke-CloneGitHubRepositoryWorkflow }
}

function Show-ProjectManagement {
    param([Parameter(Mandatory)][string]$Root)
    while ($true) {
        $items = @(
            (New-MenuItem -Label 'New Project Setup' -Desc 'Create An Empty Local Folder Or Clone A GitHub Repository.' -Value 'setup' -Icon 'Folder'),
            (New-MenuItem -Label 'Repository Connection' -Desc 'Connect, Verify, Change, Or Remove Local Remote Settings.' -Value 'connection' -Icon 'Connect'),
            (New-MenuItem -Label 'Local Changes' -Desc 'Review, Stage, Unstage, And Commit Individual Changes.' -Value 'changes' -Icon 'Stage'),
            (New-MenuItem -Label 'Remote Synchronization' -Desc 'Review Upstream Status, Fetch, Pull Safely, And Push.' -Value 'sync' -Icon 'Sync'),
            (New-MenuItem -Label 'Branch Management' -Desc 'List, Create, Switch, Rename, Delete Safely, And Track Branches.' -Value 'branches' -Icon 'Branch'),
            (New-MenuItem -Label 'Repository Status' -Desc 'Review Current Branch, Changes, Upstream, Remotes, And Last Commit.' -Value 'status' -Icon 'Status'),
            (New-MenuItem -Label 'History And Recovery' -Desc 'Review Recent Commits Or Use Existing Safe Recovery Workflows.' -Value 'history' -Icon 'History'),
            (New-MenuItem -Label 'GitHub Account' -Desc 'Check GitHub CLI Availability And Authentication.' -Value 'account' -Icon 'GitHub'),
            (New-MenuItem -Label 'GitHub Page Management' -Desc 'Create A Repository Or Update Its Description, Homepage, Topics, And Visibility.' -Value 'github' -Icon 'Page'),
            (New-MenuItem -Label 'Advanced Repository Management' -Desc 'Initialize Git, Add A General Remote, Or Open The Full Command Explorer.' -Value 'advanced' -Icon 'Command'),
            (New-MenuItem -Label 'Select Workspace Folder' -Desc 'Choose Another Local Project Folder.' -Value 'workspace' -Icon 'Folder'),
            (New-MenuItem -Label 'Return To Task Dashboard' -Desc 'Open The Main Dashboard And Workspace Categories.' -Value '__dashboard' -Icon 'Dashboard'),
            (New-MenuItem -Label 'Interface Mode Settings' -Desc 'Switch Interface Immediately And Save The Preference.' -Value '__settings' -Icon 'Settings')
        )
        $choice = Show-Menu -Title 'Project Management' -Description 'Manage Local Git State And Its GitHub Connection Through The Shared Git Engine.' -Items $items -Navigation Arrows -Preset 'task-dashboard'
        if (-not $choice) { return }
        if ($choice -eq '__dashboard') { return '__interface:Dashboard' }
        if ($choice -eq '__settings') {
            $mode = Show-InterfaceSettings
            if ($mode) { return ('__interface:' + $mode) }
            continue
        }
        if ($choice -eq 'workspace') { Select-Workspace; continue }
        $route = Show-ProjectManagementCategory -Category $choice -Root $Root
        if ($route -and $route.StartsWith('__interface:')) { return $route }
    }
}

function Show-ProjectManagementRemoteCategory {
    $items = @(
        (New-MenuItem -Label 'Review Remote Synchronization Status' -Desc 'Check Current Upstream And Ahead/Behind Counts.' -Value 'status' -Icon 'Status'),
        (New-MenuItem -Label 'Fetch Remote Changes' -Desc 'Download Remote References Without Changing Working Files.' -Value 'fetch' -Icon 'Fetch'),
        (New-MenuItem -Label 'Update From Remote' -Desc 'Use Fast-Forward-Only Pull After Local Preflight.' -Value 'pull' -Icon 'Pull'),
        (New-MenuItem -Label 'Push Local Commits' -Desc 'Push To The Current Upstream Or Set One Explicitly.' -Value 'push' -Icon 'Push')
    )
    $choice = Show-ProjectActionMenu -Title 'Remote Synchronization' -Description 'Fetch, Pull, And Push Are Reviewed Separately. Force Push Is Not Offered.' -Items $items
    if ($choice -like '__interface:*') { return $choice }
    if ($choice -eq '__back' -or -not $choice) { return }
    if ($choice -eq 'status') { Show-ProjectRepositoryStatus } else { Invoke-RemoteSyncWorkflow -Operation $choice }
}

function Show-ProjectManagementHistoryCategory {
    $items = @(
        (New-MenuItem -Label 'Review Recent Commit History' -Desc 'Read The Latest Eight Commits Without Changing Repository State.' -Value 'log' -Icon 'History'),
        (New-MenuItem -Label 'Undo And Recovery Options' -Desc 'Review Restore, Revert, And Reflog Workflows.' -Value 'undo' -Icon 'Undo')
    )
    $choice = Show-ProjectActionMenu -Title 'History And Recovery' -Description 'History Rewrites And Hard Resets Are Not Available Here.' -Items $items
    if ($choice -like '__interface:*') { return $choice }
    if ($choice -eq '__back' -or -not $choice) { return }
    if ($choice -eq 'log') { Show-RecentProjectHistory } else { Invoke-UndoWorkflow }
}

function Show-ProjectManagementAdvancedCategory {
    param([Parameter(Mandatory)][string]$Root)
    $items = @(
        (New-MenuItem -Label 'Initialize Local Repository' -Desc 'Create Git Metadata Only After An Explicit Confirmation.' -Value 'init' -Icon 'Initialize'),
        (New-MenuItem -Label 'Add Another Remote' -Desc 'Add An Additional Remote Through The Shared Git Engine.' -Value 'remote' -Icon 'Remote'),
        (New-MenuItem -Label 'Command Explorer' -Desc 'Browse The Installed Git Command Inventory With Risk Review.' -Value 'explorer' -Icon 'Command')
    )
    $choice = Show-ProjectActionMenu -Title 'Advanced Repository Management' -Description 'General Git Commands Use The Same Inventory, Process Boundary, And Risk Policy.' -Items $items
    if ($choice -like '__interface:*') { return $choice }
    if ($choice -eq '__back' -or -not $choice) { return }
    if ($choice -eq 'init') { Initialize-Repository }
    elseif ($choice -eq 'remote') { Invoke-RemoteWorkflow }
    else { Show-CommandExplorer $Root $false }
}

function Show-ProjectManagementCategory {
    param([Parameter(Mandatory)][string]$Category, [Parameter(Mandatory)][string]$Root)
    switch ($Category) {
        'setup' { return (Show-NewProjectSetup) }
        'connection' {
            $items = @(
                (New-MenuItem -Label 'Connect Existing GitHub Repository' -Desc 'Validate A GitHub URL And Reachability Before Adding A Local Remote.' -Value 'connect' -Icon 'Connect'),
                (New-MenuItem -Label 'Add Another Remote' -Desc 'Add A Non-GitHub Or Additional Remote Through The Shared Git Engine.' -Value 'add' -Icon 'Remote'),
                (New-MenuItem -Label 'Change Remote URL' -Desc 'Verify A New GitHub URL Before Replacing The Local Remote Setting.' -Value 'change' -Icon 'Connect'),
                (New-MenuItem -Label 'Remove Remote Configuration' -Desc 'Remove Only The Local Remote Entry, Not The GitHub Repository.' -Value 'remove' -Icon 'Warning'),
                (New-MenuItem -Label 'Verify Remote Connection' -Desc 'Check Git Access To A Selected Remote Without Changing Files.' -Value 'verify' -Icon 'Status')
            )
            $choice = Show-ProjectActionMenu -Title 'Repository Connection' -Description 'Local History Is Preserved When Remote Settings Change.' -Items $items
            if ($choice -like '__interface:*') { return $choice }
            if ($choice -eq '__back' -or -not $choice) { return }
            switch ($choice) { 'connect' { Invoke-ConnectGitHubWorkflow }; 'add' { Invoke-RemoteWorkflow }; 'change' { Invoke-ChangeRemoteUrlWorkflow }; 'remove' { Invoke-RemoveRemoteWorkflow }; 'verify' { Show-RemoteVerification } }
            return
        }
        'changes' {
            $items = @(
                (New-MenuItem -Label 'Review Local Changes' -Desc 'See Staged, Unstaged, And Untracked Files Before Editing The Index.' -Value 'review' -Icon 'Status'),
                (New-MenuItem -Label 'Stage One File' -Desc 'Choose A Specific File For The Staging Area.' -Value 'stage' -Icon 'Stage'),
                (New-MenuItem -Label 'Stage All Changes' -Desc 'Review A Confirmation Before Staging Every Changed Path.' -Value 'stage-all' -Icon 'Stage'),
                (New-MenuItem -Label 'Unstage One File' -Desc 'Remove One Path From Staging Without Discarding Its Working File.' -Value 'unstage' -Icon 'Unstage'),
                (New-MenuItem -Label 'Create A Commit' -Desc 'Review The Staged Snapshot And Save A Local Commit.' -Value 'commit' -Icon 'Commit')
            )
            $choice = Show-ProjectActionMenu -Title 'Local Changes' -Description 'Staging And Committing Are Separate Steps. Push Is Separate From Commit.' -Items $items
            if ($choice -like '__interface:*') { return $choice }
            if ($choice -eq '__back' -or -not $choice) { return }
            switch ($choice) { 'review' { Show-ProjectChangeReview }; 'stage' { Invoke-StageWorkflow }; 'stage-all' { Invoke-StageAllWorkflow }; 'unstage' { Invoke-UnstageWorkflow }; 'commit' { Invoke-CommitWorkflow } }
            return
        }
        'sync' { return (Show-ProjectManagementRemoteCategory) }
        'branches' { return (Show-BranchManagement) }
        'status' { Show-ProjectRepositoryStatus; return }
        'history' { return (Show-ProjectManagementHistoryCategory) }
        'account' { Show-GitHubAuthenticationStatus; return }
        'github' { return (Show-GitHubPageManagement) }
        'advanced' { return (Show-ProjectManagementAdvancedCategory -Root $Root) }
    }
}
function Show-InterfaceSettings {
    $items=@(
        (New-MenuItem -Label 'Task Dashboard' -Desc 'Organized Categories And Repository Overview.' -Value 'Dashboard' -Icon 'Dashboard'),
        (New-MenuItem -Label 'Command Palette' -Desc 'Search The Installed Git Command Inventory.' -Value 'Palette' -Icon 'Search'),
        (New-MenuItem -Label 'Assistant Console' -Desc 'Guided Git Workflows And Confirmations.' -Value 'Assistant' -Icon 'Form')
    )
    $choice=Show-Menu -Title ('Interface Mode (Now: ' + (Get-InterfaceMode) + ')') -Description 'Applies Immediately And Persists Across Restarts.' -Items $items
    if ($choice) { Set-InterfaceMode $choice; Show-Notice -Title 'Interface Mode Saved' -Lines @($choice + ' Is Now The Preferred Interface.') -Kind Success; return $choice }
    return ''
}
function Show-AppAbout { param([string]$Root) Show-Notice -Title 'About Git Command Manager' -Lines @('Version: ' + (Get-AppVersion $Root),'Git: ' + $(if (Get-GitExecutable) { 'Available' } else { 'Not Found' }),'Interface Mode: ' + (Get-InterfaceMode)) -Kind Info }

function Get-MainMenuItems {
    return @(
        (New-MenuItem -Label 'Workspace Dashboard' -Desc 'Review Branch, Upstream, Change Counts, Remotes, And Recent Commit.' -Value 'dashboard' -Icon 'Dashboard'),
        (New-MenuItem -Label 'Select Workspace Folder' -Desc 'Choose A Local Project Folder Using Keyboard Input.' -Value 'workspace' -Icon 'Folder'),
        (New-MenuItem -Label 'Project Management' -Desc 'Connect Local Projects, Manage GitHub Remotes, And Update Repository Pages.' -Value 'projects' -Icon 'Project'),
        (New-MenuItem -Label 'Initialize Repository' -Desc 'Create Repository Metadata Only After Confirmation.' -Value 'init' -Icon 'Initialize'),
        (New-MenuItem -Label 'Stage A File' -Desc 'Choose Individual Files To Add To Staging.' -Value 'stage' -Icon 'Stage'),
        (New-MenuItem -Label 'Create A Commit' -Desc 'Review Staged Changes And Save A Local Snapshot.' -Value 'commit' -Icon 'Commit'),
        (New-MenuItem -Label 'Create A Branch' -Desc 'Validate A Branch Name And Switch To It.' -Value 'branch' -Icon 'Branch'),
        (New-MenuItem -Label 'Add A Remote' -Desc 'Connect To A Remote Without Showing Credentials.' -Value 'remote' -Icon 'Remote'),
        (New-MenuItem -Label 'Fetch Remote Changes' -Desc 'Download Remote References Without Changing Files.' -Value 'fetch' -Icon 'Fetch'),
        (New-MenuItem -Label 'Update From Remote' -Desc 'Use A Fast-Forward-Only Update.' -Value 'pull' -Icon 'Pull'),
        (New-MenuItem -Label 'Push Local Commits' -Desc 'Send Local Commits To The Configured Upstream.' -Value 'push' -Icon 'Push'),
        (New-MenuItem -Label 'Undo And Recovery' -Desc 'Review Restore, Revert, And Reflog Options.' -Value 'undo' -Icon 'Undo'),
        (New-MenuItem -Label 'Command Explorer' -Desc 'Browse Every Installed Git Command.' -Value 'explorer' -Icon 'Command'),
        (New-MenuItem -Label 'Command Palette' -Desc 'Search The Shared Git Command Engine.' -Value 'palette' -Icon 'Search'),
        (New-MenuItem -Label 'Assistant Console' -Desc 'Use Guided Git Workflows.' -Value 'assistant' -Icon 'Form'),
        (New-MenuItem -Label 'Interface Mode' -Desc 'Set The Preferred Startup Interface.' -Value 'settings' -Icon 'Settings'),
        (New-MenuItem -Label 'About' -Desc 'Show Application And Git Details.' -Value 'about' -Icon 'About'),
        (New-MenuItem -Label 'Exit' -Desc 'Close Git Command Manager.' -Value 'exit' -Icon 'Exit')
    )
}

function Invoke-MainChoice {
    param([string]$Choice,[string]$Root)
    switch ($Choice) {
        'dashboard' { Show-WorkspaceDashboard }
        'workspace' { Select-Workspace }
        'projects' { return (Show-ProjectManagement -Root $Root) }
        'init' { Initialize-Repository }
        'stage' { Invoke-StageWorkflow }
        'commit' { Invoke-CommitWorkflow }
        'branch' { Invoke-BranchWorkflow }
        'remote' { Invoke-RemoteWorkflow }
        'fetch' { Invoke-RemoteSyncWorkflow 'fetch' }
        'pull' { Invoke-RemoteSyncWorkflow 'pull' }
        'push' { Invoke-RemoteSyncWorkflow 'push' }
        'undo' { Invoke-UndoWorkflow }
        'explorer' { return (Show-CommandExplorer $Root $false) }
        'palette' { return (Show-CommandExplorer $Root $true) }
        'assistant' { return (Start-AssistantConsole $Root) }
        'settings' { return (Show-InterfaceSettings) }
        'about' { Show-AppAbout $Root }
    }
}
function Start-AssistantConsole {
    param([string]$Root)
    $items=@(
        (New-MenuItem -Label 'Check Repository Status' -Desc 'Explain Repository Changes Before Taking Action.' -Value 'dashboard' -Icon 'Status'),
        (New-MenuItem -Label 'Project Management' -Desc 'Guided Local Project, GitHub Connection, And Repository Page Workflows.' -Value 'projects' -Icon 'Project'),
        (New-MenuItem -Label 'Stage A File' -Desc 'Select Specific Files To Add To Staging.' -Value 'stage' -Icon 'Stage'),
        (New-MenuItem -Label 'Create A Commit' -Desc 'Review Staged Changes And Save A Local Snapshot.' -Value 'commit' -Icon 'Commit'),
        (New-MenuItem -Label 'Create A Branch' -Desc 'Validate A Branch Name And Switch To It.' -Value 'branch' -Icon 'Branch'),
        (New-MenuItem -Label 'Add A Remote' -Desc 'Connect This Repository To A Remote URL.' -Value 'remote' -Icon 'Remote'),
        (New-MenuItem -Label 'Fetch Remote Changes' -Desc 'Download Remote References Without Changing Files.' -Value 'fetch' -Icon 'Fetch'),
        (New-MenuItem -Label 'Update From Remote' -Desc 'Use Fast-Forward-Only Update After Local Preflight.' -Value 'pull' -Icon 'Pull'),
        (New-MenuItem -Label 'Push Local Commits' -Desc 'Send Commits To The Configured Or Explicit Upstream.' -Value 'push' -Icon 'Push'),
        (New-MenuItem -Label 'Undo And Recovery' -Desc 'Review Restore, Revert, And Reflog Options.' -Value 'undo' -Icon 'Undo'),
        (New-MenuItem -Label 'Initialize Repository' -Desc 'Create Git Metadata After Confirmation.' -Value 'init' -Icon 'Initialize'),
        (New-MenuItem -Label 'Browse All Commands' -Desc 'Use The Shared Command Inventory.' -Value 'browse' -Icon 'Command'),
        (New-MenuItem -Label 'Interface Mode Settings' -Desc 'Switch Interfaces Immediately And Save The Preference.' -Value 'settings' -Icon 'Settings'),
        (New-MenuItem -Label 'Return To Task Dashboard' -Desc 'Open The Main Menu And Workspace Categories.' -Value 'back' -Icon 'Dashboard')
    )
    $choice=Show-Menu -Title 'Assistant Console' -Description 'Guided Questions, Explanations, And Confirmations.' -Items $items -Navigation Arrows -Preset 'assistant-console'
    if ($choice -eq 'back' -or -not $choice) { return '__interface:Dashboard' }
    if ($choice -eq 'settings') { $mode=Show-InterfaceSettings; if ($mode) { return ('__interface:' + $mode) }; return '__interface:Assistant' }
    if ($choice -eq 'projects') { $route=Show-ProjectManagement -Root $Root; if ($route -and $route.StartsWith('__interface:')) { return $route }; return '__interface:Assistant' }
    if ($choice -eq 'browse') { $route=Show-CommandExplorer $Root $true; if ($route -and $route.StartsWith('__interface:')) { return $route }; return '__interface:Assistant' }
    if ($choice -eq 'dashboard') { Show-WorkspaceDashboard; return '__interface:Assistant' }
    if ($choice) { Invoke-MainChoice -Choice $choice -Root $Root; return '__interface:Assistant' }
}

function Start-TuiApp {
    param([string]$Root)
    Apply-AppDesign $Root
    if (-not (Get-GitExecutable)) { Show-Notice -Title 'Git Is Not Installed' -Lines @('Install Git Yourself, Then Restart This Application.') -Kind Warning; return }
    $quit=$false
    $mode=Get-InterfaceMode
    while (-not $quit) {
        if ($mode -eq 'Palette') {
            $route=Show-CommandExplorer $Root $true
            if ($route -and $route.StartsWith('__interface:')) { $mode=$route.Substring(12) } else { $mode='Dashboard' }
            continue
        }
        if ($mode -eq 'Assistant') {
            $route=Start-AssistantConsole $Root
            if ($route -and $route.StartsWith('__interface:')) { $mode=$route.Substring(12) } else { $mode='Dashboard' }
            continue
        }
        $choice=Show-Menu -Title 'Git Command Manager' -Description 'Discover Git Safely Through Dashboard, Search, Or Guided Workflows.' -Items (Get-MainMenuItems) -Navigation Arrows -Preset 'task-dashboard'
        if ($choice -eq 'exit' -or -not $choice) { $quit=$true; continue }
        if ($choice -eq 'dashboard') {
            $route=Show-CategoryDashboard $Root
            if ($route -and $route.StartsWith('__interface:')) { $mode=$route.Substring(12) }
            continue
        }
        if ($choice -eq 'settings') {
            $selectedMode=Show-InterfaceSettings
            if ($selectedMode) { $mode=$selectedMode } else { $mode=Get-InterfaceMode }
            continue
        }
        $route=Invoke-MainChoice -Choice $choice -Root $Root
        if ($route -and $route.StartsWith('__interface:')) { $mode=$route.Substring(12) }
    }
}
Export-ModuleMember -Function Get-AppVersion, Test-PersonName, Get-AppDesign, Apply-AppDesign, Get-InterfaceMode, Set-InterfaceMode, Start-TuiApp
