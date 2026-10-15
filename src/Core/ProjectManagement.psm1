# ProjectManagement.psm1 - Shared repository and GitHub project management domain services.
Set-StrictMode -Version 2.0

function Test-GitHubRepositoryUrl {
    param([Parameter(Mandatory)][string]$Url)
    $value = $Url.Trim()
    $invalid = [pscustomobject]@{ IsValid=$false; Owner=''; Repository=''; Url=''; Error='Enter A Valid GitHub Repository URL.' }
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match '[\r\n\s?#]' -or $value -match '^https?://[^/]*@') { return $invalid }
    $patterns = @(
        @{ Regex='\Ahttps://github\.com/(?<owner>[A-Za-z0-9_.-]+)/(?<repo>[A-Za-z0-9_.-]+?)(?:\.git)?/?\z'; Style='https' },
        @{ Regex='\Assh://git@github\.com/(?<owner>[A-Za-z0-9_.-]+)/(?<repo>[A-Za-z0-9_.-]+?)(?:\.git)?/?\z'; Style='ssh-uri' },
        @{ Regex='\Agit@github\.com:(?<owner>[A-Za-z0-9_.-]+)/(?<repo>[A-Za-z0-9_.-]+?)(?:\.git)?/?\z'; Style='ssh-scp' }
    )
    foreach ($item in $patterns) {
        $match = [regex]::Match($value, $item.Regex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $match.Success) { continue }
        $owner = $match.Groups['owner'].Value
        $repository = $match.Groups['repo'].Value
        if ($owner -in @('.', '..') -or $repository -in @('.', '..')) { return $invalid }
        if ($item.Style -eq 'ssh-scp') { $normalized = 'git@github.com:' + $owner + '/' + $repository + '.git' }
        elseif ($item.Style -eq 'ssh-uri') { $normalized = 'ssh://git@github.com/' + $owner + '/' + $repository + '.git' }
        else { $normalized = 'https://github.com/' + $owner + '/' + $repository + '.git' }
        return [pscustomobject]@{ IsValid=$true; Owner=$owner; Repository=$repository; Url=$normalized; Error='' }
    }
    return $invalid
}

function Format-SafeRemoteUrl {
    param([AllowEmptyString()][string]$Url)
    if ([string]::IsNullOrEmpty($Url)) { return '' }
    $safe = $Url.Trim()
    if ($safe -match '\A(?<scheme>[A-Za-z][A-Za-z0-9+.-]*://)(?<userinfo>[^/@]+)@(?<host>[^/]+)(?<path>/.*)?\z') {
        $user = '***'
        if ($Matches['userinfo'] -eq 'git') { $user = 'git' }
        $path = [string]$Matches['path']
        $safe = [string]$Matches['scheme'] + $user + '@' + [string]$Matches['host'] + $path
    } elseif ($safe -match '\A(?<user>[^/:@\s]+)(?::[^@\s]*)?@(?<host>[^:/\s]+)(?<path>:.+)\z') {
        $user = '***'
        if ($Matches['user'] -eq 'git') { $user = 'git' }
        $safe = $user + '@' + [string]$Matches['host'] + [string]$Matches['path']
    }
    if ($safe -match '\A(?<base>[^?#]+)[?#].*\z') { $safe = [string]$Matches['base'] + ' [Query Hidden]' }
    return $safe
}

function Test-GitRemoteName {
    param([Parameter(Mandatory)][string]$Name)
    return ($Name -match '\A[A-Za-z0-9][A-Za-z0-9._-]*\z')
}

function New-GitPushArguments {
    param([Parameter(Mandatory)][string]$Remote, [Parameter(Mandatory)][string]$Branch, [Parameter(Mandatory)][bool]$HasUpstream)
    if (-not (Test-GitRemoteName $Remote)) { throw 'Enter A Valid Remote Name.' }
    if ($Branch.StartsWith('-') -or [string]::IsNullOrWhiteSpace($Branch)) { throw 'Enter A Valid Branch Name.' }
    if ($HasUpstream) { return @('push') }
    return @('push','--set-upstream',$Remote,$Branch)
}

function New-GitHubRepositoryArguments {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Path, [string]$RemoteName='origin', [ValidateSet('private','public')][string]$Visibility='private')
    if ($Name -notmatch '\A[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)?\z' -or $Name.StartsWith('-')) { throw 'Enter A Valid Repository Name, Such As Owner/Project.' }
    if (-not (Test-GitRemoteName $RemoteName)) { throw 'Enter A Valid Remote Name.' }
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'A Local Repository Path Is Required.' }
    $fullPath = [IO.Path]::GetFullPath($Path)
    $result = @('repo','create',$Name,'--source',$fullPath,'--remote',$RemoteName)
    if ($Visibility -eq 'private') { $result += '--private' } else { $result += '--public' }
    return $result
}

function New-GitHubMetadataArguments {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [AllowEmptyString()][string]$Description,
        [string]$Homepage,
        [string[]]$AddTopics=@(),
        [string[]]$RemoveTopics=@(),
        [string]$Visibility=''
    )
    if ($Repository -notmatch '\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z') { throw 'Use The Explicit Owner/Repository Name.' }
    $result = @('repo','edit',$Repository)
    $hasChange = $false
    if ($PSBoundParameters.ContainsKey('Description')) {
        if ($Description.Length -gt 350 -or $Description -match '[\r\n]') { throw 'Description Must Be One Line Of 350 Characters Or Fewer.' }
        $result += @('--description',$Description)
        $hasChange = $true
    }
    if ($PSBoundParameters.ContainsKey('Homepage')) {
        $parsed = $null
        if (-not [uri]::TryCreate($Homepage,[UriKind]::Absolute,[ref]$parsed) -or $parsed.Scheme -ne 'https' -or $parsed.UserInfo) { throw 'Homepage Must Be A Valid HTTPS URL Without Embedded Credentials.' }
        $result += @('--homepage',$Homepage)
        $hasChange = $true
    }
    foreach ($topic in $AddTopics) {
        if ($topic -notmatch '\A[a-z0-9][a-z0-9-]{0,49}\z') { throw 'Topics Must Use Lowercase Letters, Numbers, And Hyphens.' }
        $result += @('--add-topic',$topic)
        $hasChange = $true
    }
    foreach ($topic in $RemoveTopics) {
        if ($topic -notmatch '\A[a-z0-9][a-z0-9-]{0,49}\z') { throw 'Topics Must Use Lowercase Letters, Numbers, And Hyphens.' }
        $result += @('--remove-topic',$topic)
        $hasChange = $true
    }
    if ($Visibility) {
        if ($Visibility -notin @('private','public')) { throw 'Choose Private Or Public Visibility.' }
        $result += @('--visibility',$Visibility,'--accept-visibility-change-consequences')
        $hasChange = $true
    }
    if (-not $hasChange) { throw 'Choose At Least One Repository Page Setting To Change.' }
    return $result
}

function Get-GitHubCliState {
    $executable = Find-Executable 'gh'
    if (-not $executable) { return [pscustomobject]@{ Available=$false; Authenticated=$false; Version=''; Error='GitHub CLI Is Not Installed.' } }
    $version = Invoke-External -FilePath $executable -Arguments @('--version') -TimeoutSec 10
    if (-not $version.Started -or $version.ExitCode -ne 0) { return [pscustomobject]@{ Available=$false; Authenticated=$false; Version=''; Error='GitHub CLI Could Not Be Started.' } }
    $auth = Invoke-External -FilePath $executable -Arguments @('auth','status') -TimeoutSec 15
    return [pscustomobject]@{ Available=$true; Authenticated=($auth.Started -and $auth.ExitCode -eq 0); Version=($version.StdOut -split '[\r\n]')[0]; Error='' }
}

function Invoke-GitHubCli {
    param([Parameter(Mandatory)][string[]]$Arguments, [string]$WorkingDirectory='', [int]$TimeoutSec=60)
    $state = Get-GitHubCliState
    if (-not $state.Available) { return [pscustomobject]@{ Started=$false; ExitCode=-1; StdOut=''; StdErr='GitHub CLI Is Not Installed.'; TimedOut=$false; Error=$state.Error } }
    if (-not $state.Authenticated) { return [pscustomobject]@{ Started=$false; ExitCode=-1; StdOut=''; StdErr='Sign In With GitHub CLI Before This Operation.'; TimedOut=$false; Error='GitHub CLI Authentication Is Required.' } }
    $exe = Find-Executable 'gh'
    return Invoke-External -FilePath $exe -Arguments $Arguments -TimeoutSec $TimeoutSec -WorkingDirectory $WorkingDirectory
}

function Get-ProjectRemoteInventory {
    param([Parameter(Mandatory)][string]$Path)
    $names = Invoke-Git -Arguments @('remote') -WorkingDirectory $Path -TimeoutSec 15
    if (-not $names.Started -or $names.ExitCode -ne 0) { return @() }
    $result = @()
    foreach ($name in @($names.StdOut -split '[\r\n]+' | Where-Object { $_ })) {
        $fetch = Invoke-Git -Arguments @('remote','get-url',$name) -WorkingDirectory $Path -TimeoutSec 15
        if ($fetch.ExitCode -ne 0) { continue }
        $push = Invoke-Git -Arguments @('remote','get-url','--push',$name) -WorkingDirectory $Path -TimeoutSec 15
        $pushUrl = if ($push.ExitCode -eq 0) { $push.StdOut.Trim() } else { $fetch.StdOut.Trim() }
        $result += [pscustomobject]@{ Name=$name; Url=(Format-SafeRemoteUrl $fetch.StdOut.Trim()); PushUrl=(Format-SafeRemoteUrl $pushUrl) }
    }
    return $result
}

function Get-GitBranchInventory {
    param([Parameter(Mandatory)][string]$Path, [switch]$Remote)
    $reference = if ($Remote) { 'refs/remotes' } else { 'refs/heads' }
    $result = Invoke-Git -Arguments @('for-each-ref','--format=%(refname:short)%09%(upstream:short)%09%(objectname:short)',$reference) -WorkingDirectory $Path -TimeoutSec 15
    if (-not $result.Started -or $result.ExitCode -ne 0) { return @() }
    $items = @()
    foreach ($line in @($result.StdOut -split '[\r\n]+' | Where-Object { $_ })) {
        $parts = $line -split [char]9,3
        $items += [pscustomobject]@{ Name=$parts[0]; Upstream=$(if ($parts.Count -gt 1) { $parts[1] } else { '' }); Commit=$(if ($parts.Count -gt 2) { $parts[2] } else { '' }) }
    }
    return $items
}

function Get-ProjectManagementSnapshot {
    param([Parameter(Mandatory)][string]$Path)
    $workspace = Get-GitWorkspaceState $Path
    if (-not $workspace.IsRepository -or $workspace.IsBare) {
        return [pscustomobject]@{ IsRepository=$workspace.IsRepository; IsBare=$workspace.IsBare; Path=$workspace.Path; Root=$workspace.Root; Branch=$workspace.Branch; Head=$workspace.Head; Staged=$workspace.Staged; Unstaged=$workspace.Unstaged; Untracked=$workspace.Untracked; Operation=$workspace.Operation; Remotes=@(); Upstream=''; Ahead=0; Behind=0; LastCommit='' }
    }
    $upstreamResult = Invoke-Git -Arguments @('rev-parse','--abbrev-ref','--symbolic-full-name','@{upstream}') -WorkingDirectory $workspace.Root -TimeoutSec 15
    $upstream = if ($upstreamResult.ExitCode -eq 0) { $upstreamResult.StdOut.Trim() } else { '' }
    $ahead = 0
    $behind = 0
    if ($upstream) {
        $counts = Invoke-Git -Arguments @('rev-list','--left-right','--count','HEAD...@{upstream}') -WorkingDirectory $workspace.Root -TimeoutSec 20
        if ($counts.ExitCode -eq 0) {
            $values = @($counts.StdOut.Trim() -split '\s+')
            if ($values.Count -ge 2) { [void][int]::TryParse($values[0],[ref]$ahead); [void][int]::TryParse($values[1],[ref]$behind) }
        }
    }
    $lastResult = Invoke-Git -Arguments @('log','-1','--format=%h%x1f%s%x1f%aI') -WorkingDirectory $workspace.Root -TimeoutSec 15
    $lastCommit = ''
    if ($lastResult.ExitCode -eq 0) {
        $parts = $lastResult.StdOut.Trim() -split [char]31,3
        $lastCommit = $parts -join ' | '
    }
    return [pscustomobject]@{
        IsRepository=$true; IsBare=$false; Path=$workspace.Path; Root=$workspace.Root; Branch=$workspace.Branch; Head=$workspace.Head
        Staged=$workspace.Staged; Unstaged=$workspace.Unstaged; Untracked=$workspace.Untracked; Operation=$workspace.Operation
        Remotes=@(Get-ProjectRemoteInventory $workspace.Root); Upstream=$upstream; Ahead=$ahead; Behind=$behind; LastCommit=$lastCommit
    }
}

function Test-GitRemoteConnection {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Remote)
    $remoteResult = Invoke-Git -Arguments @('remote','get-url',$Remote) -WorkingDirectory $Path -TimeoutSec 15
    if ($remoteResult.ExitCode -ne 0) { return [pscustomobject]@{ Reachable=$false; Remote=$Remote; Url=''; Error='The Remote Is Not Configured.' } }
    $url = $remoteResult.StdOut.Trim()
    $probe = Invoke-Git -Arguments @('ls-remote',$Remote,'HEAD') -WorkingDirectory $Path -TimeoutSec 30
    return [pscustomobject]@{ Reachable=($probe.Started -and $probe.ExitCode -eq 0); Remote=$Remote; Url=(Format-SafeRemoteUrl $url); Error=$(if ($probe.ExitCode -eq 0) { '' } else { 'Could Not Reach The Remote. Check The URL And Authentication.' }) }
}

function Get-GitHubPageUrl {
    param([Parameter(Mandatory)][string]$RepositoryUrl)
    $parsed = Test-GitHubRepositoryUrl $RepositoryUrl
    if (-not $parsed.IsValid) { return '' }
    return 'https://github.com/' + $parsed.Owner + '/' + $parsed.Repository
}

function Test-NewProjectDirectoryPath {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Path)
    $invalid = [pscustomobject]@{ IsValid=$false; FullPath=''; Error='Enter A New Folder Path With An Existing Parent.' }
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -match '[\r\n]') { return $invalid }
    try { $fullPath = [IO.Path]::GetFullPath($Path.Trim()) } catch { return $invalid }
    if (Test-Path -LiteralPath $fullPath) { return [pscustomobject]@{ IsValid=$false; FullPath=$fullPath; Error='The Target Folder Already Exists.' } }
    $parent = [IO.Path]::GetDirectoryName($fullPath)
    if (-not $parent -or -not (Test-Path -LiteralPath $parent -PathType Container)) { return [pscustomobject]@{ IsValid=$false; FullPath=$fullPath; Error='Create Or Choose An Existing Parent Folder First.' } }
    return [pscustomobject]@{ IsValid=$true; FullPath=$fullPath; Error='' }
}

function New-GitCloneArguments {
    param([Parameter(Mandatory)][string]$RepositoryUrl, [Parameter(Mandatory)][string]$Path)
    $repository = Test-GitHubRepositoryUrl $RepositoryUrl
    if (-not $repository.IsValid) { throw 'Enter A Valid GitHub Repository URL.' }
    $destination = Test-NewProjectDirectoryPath $Path
    if (-not $destination.IsValid) { throw $destination.Error }
    return @('clone','--',$repository.Url,$destination.FullPath)
}

Export-ModuleMember -Function Test-GitHubRepositoryUrl, Format-SafeRemoteUrl, Test-GitRemoteName, New-GitPushArguments, New-GitHubRepositoryArguments, New-GitHubMetadataArguments, Get-GitHubCliState, Invoke-GitHubCli, Get-ProjectRemoteInventory, Get-GitBranchInventory, Get-ProjectManagementSnapshot, Test-GitRemoteConnection, Get-GitHubPageUrl, Test-NewProjectDirectoryPath, New-GitCloneArguments
