Set-TestGroup 'Static rules'
$root = Get-TestRoot
$files = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension -in '.ps1', '.psm1' -and $_.FullName -notmatch '[\\/]tests[\\/]' })
$files += @(Get-Item -LiteralPath (Join-Path $root 'tests/TestHelpers.ps1'))
$nonAscii = @(); $parseErr = @(); $forbidden = @(); $winVar = @()
foreach ($f in $files) {
    $text = [System.IO.File]::ReadAllText($f.FullName)
    if ($text -match '[^\x00-\x7F]') { $nonAscii += $f.Name }
    $tokens = $null; $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errs)
    if ($errs.Count -gt 0) { $parseErr += $f.Name }
    foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        $n = $c.GetCommandName(); if ($n -in @('Invoke-Expression', 'iex')) { $forbidden += ($f.Name + ': ' + $n) }
    }
    if ($ast.FindAll({ param($n) $n.GetType().Name -eq 'TernaryExpressionAst' }, $true).Count -gt 0) { $forbidden += ($f.Name + ': ternary operator') }
    if ($text -match '\?\?' -and $f.Name -ne 'Static.Tests.ps1') { $forbidden += ($f.Name + ': null-coalescing') }
    if ($f.Name -ne 'Platform.psm1' -and $text -match '\$Is(Windows|Linux|MacOS)\b') { $winVar += $f.Name }
}
Assert-Equal 'source files are pure ASCII (Windows PowerShell 5.1 reads BOM-less files as ANSI)' 0 $nonAscii.Count
Assert-Equal 'every source file parses without errors' 0 $parseErr.Count
Assert-Equal 'no Invoke-Expression and no PowerShell-7-only operators' 0 $forbidden.Count
Assert-Equal '$IsWindows/$IsLinux are read only in Platform.psm1' 0 $winVar.Count
$bat = Get-ChildItem -LiteralPath $root -Filter '*.bat' -File | Select-Object -First 1
if ($bat) { $b = [System.IO.File]::ReadAllBytes($bat.FullName); $lf = 0; for ($i = 1; $i -lt $b.Length; $i++) { if ($b[$i] -eq 10 -and $b[$i - 1] -ne 13) { $lf++ } }; Assert-Equal 'the .bat launcher has CRLF line endings' 0 $lf }
$versionText = (Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
Assert-True 'VERSION is exactly MAJOR.MINOR.PATCH' ($versionText -match '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$')
Assert-Equal 'runtime application version matches VERSION' $versionText (Get-AppVersion $root)
$readmeText = [IO.File]::ReadAllText((Join-Path $root 'README.md'))
Assert-True 'README has one centered title with VERSION and no duplicate subtitle' ($readmeText -match ('(?m)^<h1 align="center">Git Command Manager <sup>v' + [regex]::Escape($versionText) + '</sup></h1>\r?$') -and $readmeText -notmatch '(?m)^Git Command Manager - v')
Assert-True 'README leads with the official project header image' ($readmeText -match '(?m)^!\[Git Command Manager Official Header\]\(assets/Git-Command-Manager-Header\.png\)\r?$' -and (Test-Path -LiteralPath (Join-Path $root 'assets/Git-Command-Manager-Header.png')))
$changelogText = [IO.File]::ReadAllText((Join-Path $root 'CHANGELOG.md'))
Assert-True 'top changelog release matches VERSION' ($changelogText -match ('(?m)^## \[' + [regex]::Escape($versionText) + '\] - '))
