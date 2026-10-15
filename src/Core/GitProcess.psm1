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
    $old = ''
    try {
        if ($WorkingDirectory) { $old = (Get-Location).Path; Set-Location -LiteralPath $WorkingDirectory }
        $result = Invoke-External -FilePath $git -Arguments $Arguments -TimeoutSec $TimeoutSec
        $result | Add-Member -NotePropertyName Arguments -NotePropertyValue @($Arguments) -Force
        return $result
    } finally { if ($old) { Set-Location -LiteralPath $old } }
}

function Format-GitCommand { param([string[]]$Arguments) return 'git ' + (($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' ') }

Export-ModuleMember -Function Get-GitExecutable, Invoke-Git, Format-GitCommand
