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
    $s=Get-GitWorkspaceState $path
    if (-not $s.IsRepository) { Show-Notice -Title 'Not A Repository' -Lines @('Initialize This Folder Only If You Intend To Create Git Metadata.') -Kind Warning; return }
    $branch=$s.Branch; if (-not $branch) { $branch='Detached Or Unborn' }
    $remoteText='None'; if ($s.Remotes.Count) { $remoteText=$s.Remotes -join ', ' }
    $operation=$s.Operation; if (-not $operation) { $operation='None' }
    Show-Notice -Title 'Workspace Dashboard' -Lines @('Path: ' + $s.Root,'Branch: ' + $branch,'HEAD: ' + $s.Head,'Staged: ' + $s.Staged,'Unstaged: ' + $s.Unstaged,'Untracked: ' + $s.Untracked,'Remotes: ' + $remoteText,'Operation In Progress: ' + $operation) -Kind Info
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
    $items=@(); foreach ($record in $inventory) { $items += New-MenuItem -Label ('git ' + $record.Name) -Desc ($record.Category + '. ' + $record.Summary) -Value $record.Name -Icon 'Run' }
    $items += New-MenuItem -Label 'Return To Dashboard' -Desc 'Open Workspace Categories And Interface Settings.' -Value '__dashboard' -Icon 'Exit'
    $items += New-MenuItem -Label 'Interface Mode Settings' -Desc 'Change The Preferred Interface Immediately.' -Value '__settings' -Icon 'Settings'
    $navigation='Arrows'; $preset='task-dashboard'; $title='Command Explorer'
    if ($Palette) { $navigation='Search'; $preset='command-palette'; $title='Command Palette' }
    $choice=Show-Menu -Title $title -Description 'Commands Are Discovered From The Installed Git Version.' -Items $items -Navigation $navigation -Preset $preset
    if ($choice -eq '__settings') { Show-InterfaceSettings; return }
    if ($choice -eq '__dashboard') { return }
    if ($choice) { $selected=@($inventory | Where-Object { $_.Name -eq $choice }); if ($selected.Count) { Invoke-CommandRecord -Record $selected[0] } }
}

function Show-CategoryDashboard {
    param([string]$Root)
    $inventory=Get-Inventory $Root
    if (-not $inventory.Count) { Show-Notice -Title 'Command Discovery Failed' -Lines @('Git Help Could Not Be Read.') -Kind Error; return }
    $categories=@($inventory | ForEach-Object { $_.Category } | Sort-Object -Unique)
    $items=@(); foreach ($category in $categories) { $count=@($inventory | Where-Object { $_.Category -eq $category }).Count; $items += New-MenuItem -Label $category -Desc ($count.ToString() + ' Discovered Git Commands. Select To Browse Commands In This Category.') -Value $category -Icon 'Item' }
    $items += New-MenuItem -Label 'Workspace Overview' -Desc 'Review Repository State And Change Counts.' -Value '__workspace' -Icon 'Info'
    $items += New-MenuItem -Label 'Return To Main Menu' -Desc 'Open Settings Or Switch Interface Modes.' -Value '__back' -Icon 'Exit'
    $category=Show-Menu -Title 'Task Dashboard' -Description 'Browse Git Commands By Category Or Review The Current Workspace.' -Items $items -Navigation Arrows -Preset 'task-dashboard'
    if ($category -eq '__workspace') { Show-WorkspaceDashboard; return }
    if ($category -eq '__back' -or -not $category) { return }
    $records=@($inventory | Where-Object { $_.Category -eq $category })
    $commands=@(); foreach ($record in $records) { $commands += New-MenuItem -Label ('git ' + $record.Name) -Desc ($record.SupportLevel + '. ' + $record.Summary) -Value $record.Name -Icon 'Run' }
    $command=Show-Menu -Title $category -Description 'Select A Command To Review Its Arguments And Risk.' -Items $commands -Navigation Arrows -Preset 'file-explorer'
    if ($command) { $record=@($records | Where-Object { $_.Name -eq $command })[0]; Invoke-CommandRecord -Record $record }
}

function Invoke-StageWorkflow {
    $path=Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Staging Files.') -Kind Warning; return }
    $entries=@(Get-GitStatusEntries $path)
    if (-not $entries.Count) { Show-Notice -Title 'No Changes Found' -Lines @('The Working Tree Has No Changes To Stage.') -Kind Info; return }
    $items=@()
    foreach ($entry in $entries) { $code=$entry.Substring(0,2); $name=$entry.Substring(3); $label=$name; if ($code -eq ([string][char]63 + [string][char]63)) { $label='Untracked: ' + $name } else { $label=$code + ' ' + $name }; $items += New-MenuItem -Label $label -Desc 'Select This File For The Staging Area.' -Value $name -Icon 'Item' }
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
    $path=Get-WorkspacePath
    if (-not $path -or -not (Get-GitWorkspaceState $path).IsRepository) { Show-Notice -Title 'Repository Required' -Lines @('Select A Git Repository Before Synchronizing.') -Kind Warning; return }
    $state=Get-GitWorkspaceState $path
    if ($state.Unstaged -or $state.Untracked) { if (-not (Show-Confirm -Title 'Working Tree Has Local Changes' -Message 'Review Local Changes Before Continuing.' -YesLabel 'Continue After Review' -NoLabel 'Cancel')) { return } }
    $args=@($Operation)
    if ($Operation -eq 'push') { $args=@('push'); $title='Push Local Commits?'; $message='Send Local Commits To The Configured Remote. Force Push Is Never Added Automatically.' }
    elseif ($Operation -eq 'pull') { $args=@('pull','--ff-only'); $title='Update With Fast-Forward Only?'; $message='Fetch And Apply Remote Changes Without Creating A Merge Commit Or Rewriting History.' }
    else { $args=@('fetch'); $title='Fetch Remote Changes?'; $message='Download Remote References Without Changing Working Files.' }
    if (-not (Show-Confirm -Title $title -Message $message -YesLabel 'Continue' -NoLabel 'Cancel')) { return }
    $r=Invoke-Git -Arguments $args -WorkingDirectory $path -TimeoutSec 120
    $output=($r.StdOut + $r.StdErr).Trim()
    if ($r.ExitCode -eq 0) { Show-Notice -Title 'Remote Operation Completed' -Lines @('Git ' + $Operation + ' Finished.',$output) -Kind Success } else { Show-Notice -Title 'Remote Operation Failed' -Lines @($output) -Kind Error }
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

function Show-InterfaceSettings {
    $items=@((New-MenuItem -Label 'Task Dashboard' -Desc 'Organized Categories And Repository Overview.' -Value 'Dashboard' -Icon 'Item'),(New-MenuItem -Label 'Command Palette' -Desc 'Search The Installed Git Command Inventory.' -Value 'Palette' -Icon 'Run'),(New-MenuItem -Label 'Assistant Console' -Desc 'Guided Git Workflows And Confirmations.' -Value 'Assistant' -Icon 'Form'))
    $choice=Show-Menu -Title ('Interface Mode (Now: ' + (Get-InterfaceMode) + ')') -Description 'Applies Immediately And Persists Across Restarts.' -Items $items
    if ($choice) { Set-InterfaceMode $choice; Show-Notice -Title 'Interface Mode Saved' -Lines @($choice + ' Is Now The Preferred Interface.') -Kind Success }
}

function Show-AppAbout { param([string]$Root) Show-Notice -Title 'About Git Command Manager' -Lines @('Version: ' + (Get-AppVersion $Root),'Git: ' + $(if (Get-GitExecutable) { 'Available' } else { 'Not Found' }),'Interface Mode: ' + (Get-InterfaceMode)) -Kind Info }

function Get-MainMenuItems {
    return @((New-MenuItem -Label 'Workspace Dashboard' -Desc 'Review The Current Repository State.' -Value 'dashboard' -Icon 'Info'),(New-MenuItem -Label 'Select Workspace Folder' -Desc 'Choose A Folder Using Keyboard Input.' -Value 'workspace' -Icon 'Item'),(New-MenuItem -Label 'Initialize Repository' -Desc 'Create A Repository After Confirmation.' -Value 'init' -Icon 'Run'),(New-MenuItem -Label 'Stage A File' -Desc 'Choose Individual Files To Add To Staging.' -Value 'stage' -Icon 'Item'),(New-MenuItem -Label 'Create A Commit' -Desc 'Review Staged Changes And Save A Local Snapshot.' -Value 'commit' -Icon 'Run'),(New-MenuItem -Label 'Create A Branch' -Desc 'Validate A Branch Name And Switch To It.' -Value 'branch' -Icon 'Item'),(New-MenuItem -Label 'Add A Remote' -Desc 'Connect To A Remote Without Showing Credentials.' -Value 'remote' -Icon 'Item'),(New-MenuItem -Label 'Fetch Remote Changes' -Desc 'Download Remote References Without Changing Files.' -Value 'fetch' -Icon 'Run'),(New-MenuItem -Label 'Update From Remote' -Desc 'Use A Fast-Forward-Only Update.' -Value 'pull' -Icon 'Run'),(New-MenuItem -Label 'Push Local Commits' -Desc 'Send Local Commits To The Configured Remote.' -Value 'push' -Icon 'Run'),(New-MenuItem -Label 'Undo And Recovery' -Desc 'Review Restore, Revert, And Reflog Options.' -Value 'undo' -Icon 'Warning'),(New-MenuItem -Label 'Command Explorer' -Desc 'Browse Every Installed Git Command.' -Value 'explorer' -Icon 'Item'),(New-MenuItem -Label 'Command Palette' -Desc 'Search The Shared Git Command Engine.' -Value 'palette' -Icon 'Run'),(New-MenuItem -Label 'Assistant Console' -Desc 'Use Guided Git Workflows.' -Value 'assistant' -Icon 'Form'),(New-MenuItem -Label 'Interface Mode' -Desc 'Set The Preferred Startup Interface.' -Value 'settings' -Icon 'Settings'),(New-MenuItem -Label 'About' -Desc 'Show Application And Git Details.' -Value 'about' -Icon 'About'),(New-MenuItem -Label 'Exit' -Desc 'Close Git Command Manager.' -Value 'exit' -Icon 'Exit'))
}

function Invoke-MainChoice { param([string]$Choice,[string]$Root) switch ($Choice) { 'dashboard' { Show-WorkspaceDashboard }; 'workspace' { Select-Workspace }; 'init' { Initialize-Repository }; 'stage' { Invoke-StageWorkflow }; 'commit' { Invoke-CommitWorkflow }; 'branch' { Invoke-BranchWorkflow }; 'remote' { Invoke-RemoteWorkflow }; 'fetch' { Invoke-RemoteSyncWorkflow 'fetch' }; 'pull' { Invoke-RemoteSyncWorkflow 'pull' }; 'push' { Invoke-RemoteSyncWorkflow 'push' }; 'undo' { Invoke-UndoWorkflow }; 'explorer' { Show-CommandExplorer $Root $false }; 'palette' { Show-CommandExplorer $Root $true }; 'assistant' { Start-AssistantConsole $Root }; 'settings' { Show-InterfaceSettings }; 'about' { Show-AppAbout $Root } } }

function Start-AssistantConsole {
    param([string]$Root)
    $items=@((New-MenuItem -Label 'Check Repository Status' -Desc 'Explain Repository Changes Before Taking Action.' -Value 'dashboard' -Icon 'Info'),(New-MenuItem -Label 'Stage A File' -Desc 'Select Specific Files To Add To Staging.' -Value 'stage' -Icon 'Item'),(New-MenuItem -Label 'Create A Commit' -Desc 'Review Staged Changes And Save A Local Snapshot.' -Value 'commit' -Icon 'Run'),(New-MenuItem -Label 'Create A Branch' -Desc 'Validate A Branch Name And Switch To It.' -Value 'branch' -Icon 'Item'),(New-MenuItem -Label 'Add A Remote' -Desc 'Connect This Repository To A Remote URL.' -Value 'remote' -Icon 'Item'),(New-MenuItem -Label 'Fetch Remote Changes' -Desc 'Download Remote References Without Changing Files.' -Value 'fetch' -Icon 'Run'),(New-MenuItem -Label 'Update From Remote' -Desc 'Use A Fast-Forward-Only Update.' -Value 'pull' -Icon 'Run'),(New-MenuItem -Label 'Push Local Commits' -Desc 'Send Local Commits To The Configured Remote.' -Value 'push' -Icon 'Run'),(New-MenuItem -Label 'Undo And Recovery' -Desc 'Review Restore, Revert, And Reflog Options.' -Value 'undo' -Icon 'Warning'),(New-MenuItem -Label 'Initialize Repository' -Desc 'Create Git Metadata After Confirmation.' -Value 'init' -Icon 'Run'),(New-MenuItem -Label 'Browse All Commands' -Desc 'Use The Shared Command Inventory.' -Value 'browse' -Icon 'Item'),(New-MenuItem -Label 'Settings And Dashboard' -Desc 'Return To The Main Menu And Interface Settings.' -Value 'back' -Icon 'Exit'))
    $choice=Show-Menu -Title 'Assistant Console' -Description 'Guided Questions, Explanations, And Confirmations.' -Items $items -Navigation Arrows -Preset 'assistant-console'
    if ($choice -eq 'back') { return }
    if ($choice -eq 'browse') { Show-CommandExplorer $Root $true; return }
    if ($choice) { Invoke-MainChoice -Choice $choice -Root $Root }
}

function Start-TuiApp {
    param([string]$Root)
    Apply-AppDesign $Root
    if (-not (Get-GitExecutable)) { Show-Notice -Title 'Git Is Not Installed' -Lines @('Install Git Yourself, Then Restart This Application.') -Kind Warning; return }
    $quit=$false
    $mode=Get-InterfaceMode
    while (-not $quit) {
        if ($mode -eq 'Palette') { Show-CommandExplorer $Root $true; $mode='Dashboard'; continue }
        if ($mode -eq 'Assistant') { Start-AssistantConsole $Root; $mode='Dashboard'; continue }
        $choice=Show-Menu -Title 'Git Command Manager' -Description 'Discover Git Safely Through Dashboard, Search, Or Guided Workflows.' -Items (Get-MainMenuItems) -Navigation Arrows -Preset 'task-dashboard'
        if ($choice -eq 'exit' -or -not $choice) { $quit=$true; continue }
        if ($choice -eq 'dashboard') { Show-CategoryDashboard $Root; continue }
        if ($choice -eq 'settings') { Show-InterfaceSettings; $mode=Get-InterfaceMode; continue }
        Invoke-MainChoice -Choice $choice -Root $Root
    }
}

Export-ModuleMember -Function Get-AppVersion, Test-PersonName, Get-AppDesign, Apply-AppDesign, Get-InterfaceMode, Set-InterfaceMode, Start-TuiApp
