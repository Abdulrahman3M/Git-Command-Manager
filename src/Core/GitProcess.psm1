# GitProcess.psm1 - Trusted Git process boundary. All Git calls use argument arrays.
Set-StrictMode -Version 2.0

function Get-GitExecutable {
    $git = Find-Executable 'git'
    if (-not $git) { return $null }
    $probe = Invoke-External -FilePath $git -Arguments @('--version') -TimeoutSec 10
    if (-not $probe.Started -or $probe.ExitCode -ne 0) { return $null }
    return $git
}

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$Arguments, [string]$WorkingDirectory = '', [int]$TimeoutSec = 45)
    $git = Get-GitExecutable
    if (-not $git) { return [pscustomobject]@{ Started=$false; ExitCode=-1; StdOut=''; StdErr=''; TimedOut=$false; Error='Git Was Not Found.'; Arguments=@($Arguments) } }
    if ($WorkingDirectory -and -not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) { return [pscustomobject]@{ Started=$false; ExitCode=-1; StdOut=''; StdErr=''; TimedOut=$false; Error='The Working Folder Does Not Exist.'; Arguments=@($Arguments) } }
    $previousPrompt = $env:GIT_TERMINAL_PROMPT
    $env:GIT_TERMINAL_PROMPT = '0'
    try {
    $result = Invoke-External -FilePath $git -Arguments $Arguments -TimeoutSec $TimeoutSec -WorkingDirectory $WorkingDirectory
    $result | Add-Member -NotePropertyName Arguments -NotePropertyValue @($Arguments) -Force
    return $result
    } finally { $env:GIT_TERMINAL_PROMPT = $previousPrompt }
}

function Format-GitCommand { param([string[]]$Arguments) return 'git ' + (($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' ') }

Export-ModuleMember -Function Get-GitExecutable, Invoke-Git, Format-GitCommand
