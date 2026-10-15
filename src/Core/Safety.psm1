# Safety.psm1 - Central risk policy for every Git action.
Set-StrictMode -Version 2.0

function Get-GitRiskTier {
    param([Parameter(Mandatory)][string]$Command, [string[]]$Arguments = @())
    $all = @($Command) + @($Arguments)
    $text = ($all -join ' ').ToLowerInvariant()
    if ($text -match '(^| )(clean|prune|filter-branch|filter-repo)( |$)' -or $text -match 'reset.*--hard|push.*--force|branch.*-d') { return 'Destructive' }
    if ($text -match '(^| )(commit|add|restore|rm|mv|reset|merge|rebase|cherry-pick|revert|init|config|remote|fetch|pull|push|tag|stash)( |$)') { return 'Mutating' }
    return 'ReadOnly'
}

function Get-RiskExplanation {
    param([Parameter(Mandatory)][string]$RiskTier)
    switch ($RiskTier) {
        'Destructive' { return 'This Operation Can Remove Data Or Rewrite History. Review The Preview Carefully And Confirm Explicitly.' }
        'Mutating' { return 'This Operation Changes Repository State Or Sends Changes To A Remote. It Requires Confirmation.' }
        default { return 'This Operation Reads Repository Information And Does Not Change Files Or History.' }
    }
}

function Test-GitArgumentsSafe {
    param([string[]]$Arguments)
    foreach ($arg in @($Arguments)) { if ($null -eq $arg) { return 'An Empty Command Argument Is Not Allowed.' } }
    return $null
}

Export-ModuleMember -Function Get-GitRiskTier, Get-RiskExplanation, Test-GitArgumentsSafe
