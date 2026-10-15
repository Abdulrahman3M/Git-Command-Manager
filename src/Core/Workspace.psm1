# Workspace.psm1 - Structured repository state without parsing human-facing status text.
Set-StrictMode -Version 2.0

function Get-GitWorkspaceState {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $inside = Invoke-Git -Arguments @('rev-parse','--is-inside-work-tree') -WorkingDirectory $full -TimeoutSec 10
    $bareResult = Invoke-Git -Arguments @('rev-parse','--is-bare-repository') -WorkingDirectory $full -TimeoutSec 10
    $isBare = $bareResult.Started -and $bareResult.ExitCode -eq 0 -and $bareResult.StdOut.Trim() -eq 'true'
    if (-not $isBare -and (-not $inside.Started -or $inside.ExitCode -ne 0 -or $inside.StdOut.Trim() -ne 'true')) { return [pscustomobject]@{ Path=$full; IsRepository=$false; IsBare=$false; Root=''; Branch=''; Head=''; Staged=0; Unstaged=0; Untracked=0; Remotes=@(); Operation=''; RawStatus=@() } }
    if ($isBare) { return [pscustomobject]@{ Path=$full; IsRepository=$true; IsBare=$true; Root=$full; Branch=''; Head=''; Staged=0; Unstaged=0; Untracked=0; Remotes=@(); Operation=''; RawStatus=@() } }
    $rootResult = Invoke-Git -Arguments @('rev-parse','--show-toplevel') -WorkingDirectory $full -TimeoutSec 10
    $root = $rootResult.StdOut.Trim()
    $branchResult = Invoke-Git -Arguments @('symbolic-ref','--short','-q','HEAD') -WorkingDirectory $full -TimeoutSec 10
    $status = Invoke-Git -Arguments @('status','--porcelain=v1','-z','--branch') -WorkingDirectory $full -TimeoutSec 15
    $staged=0; $unstaged=0; $untracked=0; $entries=@($status.StdOut -split [char]0)
    for ($entryIndex=0; $entryIndex -lt $entries.Count; $entryIndex++) {
        $entry=$entries[$entryIndex]
        if ($entry.Length -lt 3 -or $entry.StartsWith('##')) { continue }
        $x=$entry.Substring(0,1); $y=$entry.Substring(1,1)
        if ($x -eq '?' -and $y -eq '?') { $untracked++; continue }
        if ($x -ne ' ') { $staged++ }
        if ($y -ne ' ') { $unstaged++ }
        if ($x -in @('R','C') -or $y -in @('R','C')) { $entryIndex++ }
    }
    $head = (Invoke-Git -Arguments @('rev-parse','--short','HEAD') -WorkingDirectory $full -TimeoutSec 10).StdOut.Trim()
    $remotesResult = Invoke-Git -Arguments @('remote') -WorkingDirectory $full -TimeoutSec 10
    $remotes = @($remotesResult.StdOut -split "`r?`n" | Where-Object { $_ })
    $operation = ''
    $gitDirectoryResult = Invoke-Git -Arguments @('rev-parse','--git-dir') -WorkingDirectory $full -TimeoutSec 10
    $gitDirectory = $gitDirectoryResult.StdOut.Trim()
    if (-not [IO.Path]::IsPathRooted($gitDirectory)) { $gitDirectory=Join-Path $full $gitDirectory }
    foreach ($marker in @(@('rebase-merge','Rebase'),@('rebase-apply','Rebase'),@('MERGE_HEAD','Merge'),@('CHERRY_PICK_HEAD','Cherry-Pick'),@('REVERT_HEAD','Revert'))) {
        $markerPath = Join-Path $gitDirectory $marker[0]
        if (Test-Path -LiteralPath $markerPath) { $operation = $marker[1]; break }
    }
    return [pscustomobject]@{ Path=$full; IsRepository=$true; IsBare=$isBare; Root=$root; Branch=$branchResult.StdOut.Trim(); Head=$head; Staged=$staged; Unstaged=$unstaged; Untracked=$untracked; Remotes=$remotes; Operation=$operation; RawStatus=$entries }
}

function Get-GitStatusEntries {
    param([Parameter(Mandatory)][string]$Path)
    $result=Invoke-Git -Arguments @('status','--porcelain=v1','-z','--branch') -WorkingDirectory $Path -TimeoutSec 15
    if (-not $result.Started -or $result.ExitCode -ne 0) { return @() }
    return @($result.StdOut -split [char]0 | Where-Object { $_ -and -not $_.StartsWith('##') })
}

function Get-GitStagedFiles {
    param([Parameter(Mandatory)][string]$Path)
    $result=Invoke-Git -Arguments @('diff','--cached','--name-only','-z') -WorkingDirectory $Path -TimeoutSec 15
    if (-not $result.Started -or $result.ExitCode -ne 0) { return @() }
    return @($result.StdOut -split [char]0 | Where-Object { $_ })
}

Export-ModuleMember -Function Get-GitWorkspaceState, Get-GitStatusEntries, Get-GitStagedFiles
