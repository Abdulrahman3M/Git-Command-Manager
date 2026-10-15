Set-TestGroup 'Project Management Domain Safety'
$validateCommand = Get-Command Test-GitHubRepositoryUrl -ErrorAction SilentlyContinue
Assert-True 'GitHub URL validator is exported from shared project management' ($null -ne $validateCommand)
if ($validateCommand) {
    $https = Test-GitHubRepositoryUrl 'https://github.com/Owner/Project'
    Assert-True 'HTTPS GitHub repository URL is normalized' ($https.IsValid -and $https.Url -eq 'https://github.com/Owner/Project.git')
    $scp = Test-GitHubRepositoryUrl 'git@github.com:Owner/Project.git'
    Assert-True 'SSH GitHub repository URL is accepted' ($scp.IsValid -and $scp.Repository -eq 'Project')
    $ssh = Test-GitHubRepositoryUrl 'ssh://git@github.com/Owner/Project'
    Assert-True 'SSH URL form is normalized' ($ssh.IsValid -and $ssh.Url -eq 'ssh://git@github.com/Owner/Project.git')
    Assert-True 'non-GitHub remote is rejected by GitHub connector' (-not (Test-GitHubRepositoryUrl 'https://example.com/Owner/Project').IsValid)
    Assert-True 'embedded credentials are rejected in repository URL' (-not (Test-GitHubRepositoryUrl 'https://token:secret@github.com/Owner/Project').IsValid)
    Assert-Equal 'remote credentials are redacted for display' 'https://***@github.com/Owner/Project.git' (Format-SafeRemoteUrl 'https://token:secret@github.com/Owner/Project.git')
    $create = @(New-GitHubRepositoryArguments -Name 'Owner/Project' -Path 'C:\Work Space\Project' -RemoteName 'origin')
    Assert-True 'repository creation is private, argument-safe, and never pushes implicitly' ($create -contains '--private' -and $create -notcontains '--public' -and $create -notcontains '--push' -and $create -contains 'C:\Work Space\Project')
    $metadata = @(New-GitHubMetadataArguments -Repository 'Owner/Project' -Description 'Git tools for teams' -Homepage 'https://example.com' -AddTopics @('powershell','git'))
    Assert-True 'repository page edits preserve spaces and supported metadata' (($metadata -join '|').Contains('--description|Git tools for teams') -and $metadata -contains '--homepage' -and $metadata -contains 'https://example.com' -and $metadata -contains '--add-topic')
    Assert-True 'visibility changes require explicit consequence acknowledgment' ((@(New-GitHubMetadataArguments -Repository 'Owner/Project' -Visibility 'public')) -contains '--accept-visibility-change-consequences')
    Assert-Equal 'push uses explicit upstream when none is configured' 'push --set-upstream origin main' ((New-GitPushArguments -Remote origin -Branch main -HasUpstream $false) -join ' ')
    Assert-Equal 'push preserves configured upstream when present' 'push' ((New-GitPushArguments -Remote origin -Branch main -HasUpstream $true) -join ' ')
}

Assert-Equal 'GitHub page URL is derived without the .git suffix' 'https://github.com/Owner/Project' (Get-GitHubPageUrl 'git@github.com:Owner/Project.git')
$multilineAccepted = $true
try { $null = New-GitHubMetadataArguments -Repository 'Owner/Project' -Description ([string]::Concat('Line One',[char]10,'Line Two')) } catch { $multilineAccepted = $false }
Assert-True 'multiline GitHub description is rejected' (-not $multilineAccepted)
$ghState = Get-GitHubCliState
Assert-True 'GitHub CLI status reports availability and authentication independently' ($null -ne $ghState.Available -and $null -ne $ghState.Authenticated)

Set-TestGroup 'Project Management Disposable Remote Integration'
$projectPath = Join-Path (Get-TestWork) 'project management repository'
$remotePath = Join-Path (Get-TestWork) 'project management bare remote.git'
[void](New-Item -ItemType Directory -Path $projectPath -Force)
$null = Invoke-Git -Arguments @('init','-q','-b','main') -WorkingDirectory $projectPath
$null = Invoke-Git -Arguments @('config','user.name','Project Test') -WorkingDirectory $projectPath
$null = Invoke-Git -Arguments @('config','user.email','project-test@example.invalid') -WorkingDirectory $projectPath
[IO.File]::WriteAllText((Join-Path $projectPath 'readme file.txt'),'Project management integration.')
$null = Invoke-Git -Arguments @('add','--','readme file.txt') -WorkingDirectory $projectPath
$null = Invoke-Git -Arguments @('commit','-m','test: create project management fixture') -WorkingDirectory $projectPath
$null = Invoke-Git -Arguments @('init','--bare','-q','--initial-branch=main',$remotePath)
$null = Invoke-Git -Arguments @('remote','add','origin',$remotePath) -WorkingDirectory $projectPath
$pushResult = Invoke-Git -Arguments (New-GitPushArguments -Remote origin -Branch main -HasUpstream $false) -WorkingDirectory $projectPath
Assert-Equal 'first push configures an upstream on the disposable remote' 0 $pushResult.ExitCode
$snapshot = Get-ProjectManagementSnapshot $projectPath
Assert-True 'project snapshot reports branch, zero divergence, and recent commit' ($snapshot.Branch -eq 'main' -and $snapshot.Upstream -eq 'origin/main' -and $snapshot.Ahead -eq 0 -and $snapshot.Behind -eq 0 -and $snapshot.LastCommit.Contains('test: create project management fixture'))
Assert-Equal 'remote inventory returns one sanitized remote' 1 (@($snapshot.Remotes).Count)
$remoteCheck = Test-GitRemoteConnection -Path $projectPath -Remote origin
Assert-Equal 'local bare remote connection verifies without network access' $true $remoteCheck.Reachable
$localBranches = @(Get-GitBranchInventory -Path $projectPath)
Assert-Equal 'local branch inventory returns its tracking branch' 'origin/main' $localBranches[0].Upstream

Set-TestGroup 'New Project And Clone Validation'
$projectCandidate = Join-Path (Get-TestWork) 'new local project folder'
$projectValidation = Test-NewProjectDirectoryPath $projectCandidate
Assert-True 'new project folder requires a valid, non-existing target and existing parent' ($projectValidation.IsValid -and $projectValidation.FullPath -eq [IO.Path]::GetFullPath($projectCandidate))
$existingValidation = Test-NewProjectDirectoryPath (Get-TestWork)
Assert-True 'existing directory is rejected as a new project target' (-not $existingValidation.IsValid)
$emptyValidation = Test-NewProjectDirectoryPath ''
Assert-True 'empty target is rejected with a validation result' (-not $emptyValidation.IsValid -and $emptyValidation.Error)
$cloneCandidate = Join-Path (Get-TestWork) 'clone destination with spaces'
$cloneArguments = @(New-GitCloneArguments -RepositoryUrl 'https://github.com/Owner/Project' -Path $cloneCandidate)
Assert-True 'clone command keeps repository and destination as separate arguments' ($cloneArguments[0] -eq 'clone' -and $cloneArguments[1] -eq '--' -and $cloneArguments[2] -eq 'https://github.com/Owner/Project.git' -and $cloneArguments[3] -eq [IO.Path]::GetFullPath($cloneCandidate))
$invalidCloneAccepted = $true
try { $null = New-GitCloneArguments -RepositoryUrl 'https://example.com/Owner/Project' -Path $cloneCandidate } catch { $invalidCloneAccepted = $false }
Assert-True 'clone URL is restricted to verified GitHub URL forms' (-not $invalidCloneAccepted)

$clonePath = Join-Path (Get-TestWork) 'cloned project with spaces'
$cloneResult = Invoke-Git -Arguments @('clone','--',$remotePath,$clonePath) -WorkingDirectory (Get-TestWork) -TimeoutSec 60
$cloneState = Get-GitWorkspaceState $clonePath
Assert-Equal 'Git clone uses the shared process boundary with a spaced destination' 0 $cloneResult.ExitCode
Assert-True 'cloned repository preserves its branch and project history' ($cloneState.IsRepository -and $cloneState.Branch -eq 'main' -and $cloneState.Head)
