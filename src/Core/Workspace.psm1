# Workspace.psm1 - Structured repository state without parsing human-facing status text.
Set-StrictMode -Version 2.0

function Get-GitWorkspaceState {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $inside = Invoke-Git -Arguments @('rev-parse','--is-inside-work-tree') -WorkingDirectory $full -TimeoutSec 10
    if (-not $inside.Started -or $inside.ExitCode -ne 0 -or $inside.StdOut.Trim() -ne 'true') { return [pscustomobject]@{ Path=$full; IsRepository=$false; IsBare=$false; Root=''; Branch=''; Head=''; Staged=0; Unstaged=0; Untracked=0; RawStatus=@() } }
    $root = (Invoke-Git -Arguments @('rev-parse','--show-toplevel') -WorkingDirectory $full -TimeoutSec 10).StdOut.Trim()
    $branchResult = Invoke-Git -Arguments @('symbolic-ref','--short','-q','HEAD') -WorkingDirectory $full -TimeoutSec 10
    $status = Invoke-Git -Arguments @('status','--porcelain=v1','-z','--branch') -WorkingDirectory $full -TimeoutSec 15
    $staged=0; $unstaged=0; $untracked=0; $entries=@($status.StdOut -split [char]0)
    foreach ($entry in $entries) { if ($entry.Length -lt 3 -or $entry.StartsWith('##')) { continue }; $x=$entry.Substring(0,1); $y=$entry.Substring(1,1); if ($x -eq '?' -and $y -eq '?') { $untracked++; continue }; if ($x -ne ' ') { $staged++ }; if ($y -ne ' ') { $unstaged++ } }
    $head = (Invoke-Git -Arguments @('rev-parse','--short','HEAD') -WorkingDirectory $full -TimeoutSec 10).StdOut.Trim()
    return [pscustomobject]@{ Path=$full; IsRepository=$true; IsBare=$false; Root=$root; Branch=$branchResult.StdOut.Trim(); Head=$head; Staged=$staged; Unstaged=$unstaged; Untracked=$untracked; RawStatus=$entries }
}

Export-ModuleMember -Function Get-GitWorkspaceState
