# GitDiscovery.psm1 - Installed command inventory, never a hard-coded command list.
Set-StrictMode -Version 2.0

function Get-GitCommandInventory {
    param([string]$WorkingDirectory = '')
    $r = Invoke-Git -Arguments @('help','-a') -WorkingDirectory $WorkingDirectory -TimeoutSec 20
    if (-not $r.Started) { return @() }
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($match in [regex]::Matches($r.StdOut + "`n" + $r.StdErr, '(?m)^\s{2,}([a-z][a-z0-9-]+)(?:\s|$)')) { [void]$names.Add($match.Groups[1].Value) }
    return @($names | Sort-Object | ForEach-Object { New-GitCommandRecord -Name $_ })
}

function Get-GitCommandCategory {
    param([string]$Name)
    $sets = @{
        'Setup And Configuration'=@('config','init','help','version'); 'Inspect And Diagnose'=@('status','diff','log','show','blame','shortlog','reflog','describe','fsck');
        'Changes And Snapshots'=@('add','restore','rm','mv','commit','reset','clean','stash'); 'Branches And Integration'=@('branch','switch','checkout','merge','rebase','cherry-pick','revert','worktree');
        'Remotes And Collaboration'=@('remote','clone','fetch','pull','push','ls-remote','request-pull','bundle'); 'Tags And Releases'=@('tag','archive');
        'Patches And Mail'=@('apply','format-patch','am','send-email'); 'Submodules And Dependencies'=@('submodule','subtree');
        'Objects And References'=@('cat-file','hash-object','rev-parse','show-ref','update-ref','symbolic-ref','for-each-ref'); 'Index And Trees'=@('ls-files','ls-tree','read-tree','write-tree','update-index','mktree');
        'Repository Maintenance'=@('gc','maintenance','repack','prune','count-objects','verify-pack','multi-pack-index'); 'Security And Signing'=@('verify-commit','verify-tag','credential')
    }
    foreach ($key in $sets.Keys) { if ($sets[$key] -contains $Name) { return $key } }
    return 'Other And Unclassified'
}

function New-GitCommandRecord {
    param([Parameter(Mandatory)][string]$Name)
    $risk = Get-GitRiskTier -Command $Name
    $guided = @('status','init','add','commit','branch','switch','remote','fetch','pull','push','restore','reset') -contains $Name
    $level = if ($risk -eq 'ReadOnly') { 'Generic' } elseif ($guided) { 'Guided' } else { 'Generic' }
    return [pscustomobject]@{ Id=('git.' + $Name); Name=$Name; Category=(Get-GitCommandCategory $Name); SupportLevel=$level; RiskTier=$risk; Summary=('Run Git ' + $Name + ' With A Preview And Explicit Consent When Needed.'); HelpSource=('git ' + $Name + ' --help'); Prerequisites=@('Git'); ParameterSchema=@(); SideEffects=(Get-RiskExplanation $risk); Verification='Check Exit Code And Refresh Repository State' }
}

function Export-GitCommandCatalog {
    param([Parameter(Mandatory)][object[]]$Inventory, [Parameter(Mandatory)][string]$Path)
    $json = @($Inventory) | ConvertTo-Json -Depth 6
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $utf8)
}

Export-ModuleMember -Function Get-GitCommandInventory, Get-GitCommandCategory, New-GitCommandRecord, Export-GitCommandCatalog
