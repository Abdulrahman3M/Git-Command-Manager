Set-TestGroup 'Git Discovery And Safety'
$version=Invoke-Git -Arguments @('--version')
Assert-True 'Git executable is available' ($version.Started -and $version.ExitCode -eq 0)
$catalog=Get-GitCommandInventory
Assert-True 'installed Git commands are discovered' ($catalog.Count -gt 0)
Assert-True 'discovered commands have catalog support metadata' ($null -ne ($catalog | Where-Object { $_.SupportLevel -and $_.Category -and $_.RiskTier } | Select-Object -First 1))
Assert-Equal 'destructive reset is classified' 'Destructive' (Get-GitRiskTier 'reset' @('--hard'))
Assert-Equal 'restore worktree is classified destructive' 'Destructive' (Get-GitRiskTier 'restore' @('--worktree','--','file'))
Assert-Equal 'unknown command receives review tier' 'RequiresReview' (Get-GitRiskTier 'future-command' @())

Set-TestGroup 'Disposable Repository Workflows'
$work=Join-Path (Get-TestWork) 'git workspace with spaces'
[void](New-Item -ItemType Directory -Path $work -Force)
$init=Invoke-Git -Arguments @('init','-q') -WorkingDirectory $work
Assert-Equal 'disposable repository initializes' 0 $init.ExitCode
$identity=Invoke-Git -Arguments @('config','user.name','Git Test') -WorkingDirectory $work
$email=Invoke-Git -Arguments @('config','user.email','git-test@example.invalid') -WorkingDirectory $work
$file=Join-Path $work 'hello world.txt'
[IO.File]::WriteAllText($file,'first line')
$state=Get-GitWorkspaceState $work
Assert-True 'untracked file is detected' ($state.IsRepository -and $state.Untracked -eq 1)
$stage=Invoke-Git -Arguments @('add','--','hello world.txt') -WorkingDirectory $work
Assert-Equal 'path with spaces stages as one argument' 0 $stage.ExitCode
Assert-Equal 'staged path is listed' 1 @(Get-GitStagedFiles $work).Count
$commit=Invoke-Git -Arguments @('commit','-m','test: create base snapshot') -WorkingDirectory $work
Assert-Equal 'disposable commit succeeds' 0 $commit.ExitCode
$branch=Invoke-Git -Arguments @('switch','-c','feature/safe-test') -WorkingDirectory $work -TimeoutSec 10
Assert-Equal 'disposable branch is created' 0 $branch.ExitCode
Assert-Equal 'branch state is reported' 'feature/safe-test' (Invoke-Git -Arguments @('symbolic-ref','--short','HEAD') -WorkingDirectory $work -TimeoutSec 10).StdOut.Trim()
$spaces=Join-Path $work 'file with spaces.txt'
[IO.File]::WriteAllText($spaces,'initial')
$null=Invoke-Git -Arguments @('add','--','file with spaces.txt') -WorkingDirectory $work
$null=Invoke-Git -Arguments @('commit','-m','test: add spaced path') -WorkingDirectory $work
[IO.File]::WriteAllText($spaces,'updated')
$restore=Invoke-Git -Arguments @('restore','--worktree','--','file with spaces.txt') -WorkingDirectory $work
Assert-Equal 'restore handles a path with spaces' 0 $restore.ExitCode
Assert-Equal 'restore returns the file to its committed content' 'initial' ([IO.File]::ReadAllText($spaces))
$remote=Invoke-Git -Arguments @('remote','add','local-origin','https://example.invalid/repo.git') -WorkingDirectory $work
Assert-Equal 'remote name is discovered without exposing its URL' 1 (Get-GitWorkspaceState $work).Remotes.Count
$bare=Join-Path (Get-TestWork) 'bare repository.git'
$bareResult=Invoke-Git -Arguments @('init','--bare','-q',$bare)
Assert-Equal 'bare repository initializes' 0 $bareResult.ExitCode
Assert-True 'bare repository is identified' ((Get-GitWorkspaceState $bare).IsRepository -and (Get-GitWorkspaceState $bare).IsBare)
$cleanState=Get-GitWorkspaceState $work
Assert-Equal 'clean repository has no staged changes' 0 $cleanState.Staged
Assert-Equal 'clean repository has no unstaged changes' 0 $cleanState.Unstaged
[IO.File]::WriteAllText((Join-Path $work 'unstaged.txt'),'unstaged')
$unstagedState=Get-GitWorkspaceState $work
Assert-Equal 'untracked changes are detected separately from unstaged changes' 2 $unstagedState.Untracked
$null=Invoke-Git -Arguments @('add','--','unstaged.txt') -WorkingDirectory $work
Assert-Equal 'staged-only path is visible to commit preflight' 1 @(Get-GitStagedFiles $work).Count
[IO.File]::WriteAllText($spaces,'mixed working tree change')
$mixedState=Get-GitWorkspaceState $work
Assert-True 'mixed staged and unstaged changes are distinguished' ($mixedState.Staged -gt 0 -and $mixedState.Unstaged -gt 0)

$renameWork=Join-Path (Get-TestWork) 'rename count repository'
[void](New-Item -ItemType Directory -Path $renameWork -Force)
$null=Invoke-Git -Arguments @('init','-q') -WorkingDirectory $renameWork
$null=Invoke-Git -Arguments @('config','user.name','Git Test') -WorkingDirectory $renameWork
$null=Invoke-Git -Arguments @('config','user.email','git-test@example.invalid') -WorkingDirectory $renameWork
[IO.File]::WriteAllText((Join-Path $renameWork 'before.txt'),'rename fixture')
$null=Invoke-Git -Arguments @('add','--','before.txt') -WorkingDirectory $renameWork
$null=Invoke-Git -Arguments @('commit','-m','test: create rename fixture') -WorkingDirectory $renameWork
$null=Invoke-Git -Arguments @('mv','--','before.txt','after.txt') -WorkingDirectory $renameWork
$renameState=Get-GitWorkspaceState $renameWork
Assert-Equal 'staged rename is counted once' 1 $renameState.Staged
Assert-Equal 'staged rename does not create a phantom unstaged path' 0 $renameState.Unstaged