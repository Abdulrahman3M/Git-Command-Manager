# Safety.psm1 - Central risk policy for all Git command surfaces.
Set-StrictMode -Version 2.0
function Get-GitRiskTier {
    param([Parameter(Mandatory)][string]$Command,[string[]]$Arguments=@())
    $name=$Command.ToLowerInvariant(); $argsText=@($Arguments) -join ' '
    if (@('clean','prune','filter-branch','filter-repo') -contains $name -or $argsText -match '(^|\s)--hard(\s|$)|(^|\s)--force(\s|$)|(^|\s)-f(\s|$)|--worktree') { return 'Destructive' }
    if ($name -in @('commit','add','restore','rm','mv','reset','merge','rebase','cherry-pick','revert','init','config','remote','fetch','pull','push','tag','stash','branch','switch','checkout','gc','maintenance','repack','update-ref','symbolic-ref','update-index','read-tree','write-tree','am','apply','submodule')) { return 'Mutating' }
    if (@('status','diff','log','show','blame','shortlog','reflog','describe','fsck','rev-parse','cat-file','ls-files','ls-tree','show-ref','for-each-ref','count-objects','verify-pack','version','help','ls-remote') -notcontains $name) { return 'RequiresReview' }
    return 'ReadOnly'
}
function Get-RiskExplanation { param([string]$RiskTier) switch ($RiskTier) { 'Destructive' { 'This Operation Can Remove Data Or Rewrite History. Review The Exact Target And Confirm Explicitly.' }; 'Mutating' { 'This Operation Changes Repository State Or Sends Data To A Remote. It Requires Confirmation.' }; 'RequiresReview' { 'This Command Is Unclassified. Review Its Documentation And Arguments Before Running It.' }; default { 'This Operation Reads Repository Information And Does Not Change Files Or History.' } } }
function Test-GitArgumentsSafe { param([string[]]$Arguments) foreach ($arg in @($Arguments)) { if ($null -eq $arg) { return 'An Empty Command Argument Is Not Allowed.' } }; return $null }
Export-ModuleMember -Function Get-GitRiskTier, Get-RiskExplanation, Test-GitArgumentsSafe
