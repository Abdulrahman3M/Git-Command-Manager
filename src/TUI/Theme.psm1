# Theme.psm1 - the ONE place for colors and icons. Other modules ask for a ROLE or an icon NAME, never a color/glyph.
# Icons come in three tiers: Emoji (modern terminals), Symbol (single-column glyphs from the Windows Glyph List 4, drawn by
# every console font) and Ascii (redirected output / forced). A new icon needs all three forms.
Set-StrictMode -Version 2.0
$script:ColorMode = 'Full'
$script:Accent = 'Cyan'
$script:Tier = ''   # the tier in use; empty = detect on first use (tests and the settings screen can override it)
$script:DetectedTier = ''

function ConvertFrom-CodePoint { param([int]$Code) return [char]::ConvertFromUtf32($Code) }

$script:IconTable = @{
    App       = @{ Emoji = (ConvertFrom-CodePoint 0x1F5C3); Symbol = (ConvertFrom-CodePoint 0x25A0); Ascii = 'G' }
    Dashboard = @{ Emoji = (ConvertFrom-CodePoint 0x1F4CA); Symbol = (ConvertFrom-CodePoint 0x25A0); Ascii = 'H' }
    Project   = @{ Emoji = (ConvertFrom-CodePoint 0x1F5C2); Symbol = (ConvertFrom-CodePoint 0x25A3); Ascii = 'P' }
    Connect   = @{ Emoji = (ConvertFrom-CodePoint 0x1F517); Symbol = (ConvertFrom-CodePoint 0x21D4); Ascii = 'C' }
    Sync      = @{ Emoji = (ConvertFrom-CodePoint 0x1F504); Symbol = (ConvertFrom-CodePoint 0x21BB); Ascii = 'S' }
    Unstage   = @{ Emoji = (ConvertFrom-CodePoint 0x1F4E4); Symbol = (ConvertFrom-CodePoint 0x25B2); Ascii = '-' }
    History   = @{ Emoji = (ConvertFrom-CodePoint 0x1F4DC); Symbol = (ConvertFrom-CodePoint 0x2261); Ascii = 'H' }
    GitHub    = @{ Emoji = (ConvertFrom-CodePoint 0x1F310); Symbol = (ConvertFrom-CodePoint 0x25C8); Ascii = 'G' }
    Page      = @{ Emoji = (ConvertFrom-CodePoint 0x1F4C4); Symbol = (ConvertFrom-CodePoint 0x25A0); Ascii = 'P' }
    Lock      = @{ Emoji = (ConvertFrom-CodePoint 0x1F512); Symbol = (ConvertFrom-CodePoint 0x25A3); Ascii = 'L' }
    Search    = @{ Emoji = (ConvertFrom-CodePoint 0x1F50E); Symbol = (ConvertFrom-CodePoint 0x25CF); Ascii = '?' }
    Command   = @{ Emoji = (ConvertFrom-CodePoint 0x2328); Symbol = (ConvertFrom-CodePoint 0x25BA); Ascii = '>' }
    Run       = @{ Emoji = (ConvertFrom-CodePoint 0x1F680); Symbol = (ConvertFrom-CodePoint 0x25BA); Ascii = '>' }
    Form      = @{ Emoji = (ConvertFrom-CodePoint 0x1F4DD); Symbol = (ConvertFrom-CodePoint 0x2666); Ascii = '*' }
    Folder    = @{ Emoji = (ConvertFrom-CodePoint 0x1F4C1); Symbol = (ConvertFrom-CodePoint 0x25A0); Ascii = 'D' }
    Status    = @{ Emoji = (ConvertFrom-CodePoint 0x1F50D); Symbol = (ConvertFrom-CodePoint 0x263A); Ascii = 'S' }
    Initialize= @{ Emoji = (ConvertFrom-CodePoint 0x1F195); Symbol = (ConvertFrom-CodePoint 0x25BA); Ascii = 'N' }
    Stage     = @{ Emoji = (ConvertFrom-CodePoint 0x1F4E5); Symbol = (ConvertFrom-CodePoint 0x25BC); Ascii = '+' }
    Commit    = @{ Emoji = (ConvertFrom-CodePoint 0x1F4BE); Symbol = (ConvertFrom-CodePoint 0x25A0); Ascii = 'C' }
    Branch    = @{ Emoji = (ConvertFrom-CodePoint 0x1F33F); Symbol = (ConvertFrom-CodePoint 0x2666); Ascii = 'B' }
    Remote    = @{ Emoji = (ConvertFrom-CodePoint 0x1F310); Symbol = (ConvertFrom-CodePoint 0x2248); Ascii = 'R' }
    Fetch     = @{ Emoji = (ConvertFrom-CodePoint 0x1F4E5); Symbol = (ConvertFrom-CodePoint 0x2193); Ascii = 'F' }
    Pull      = @{ Emoji = (ConvertFrom-CodePoint 0x2B07); Symbol = (ConvertFrom-CodePoint 0x2193); Ascii = 'v' }
    Push      = @{ Emoji = (ConvertFrom-CodePoint 0x2B06); Symbol = (ConvertFrom-CodePoint 0x2191); Ascii = '^' }
    Undo      = @{ Emoji = (ConvertFrom-CodePoint 0x21A9); Symbol = (ConvertFrom-CodePoint 0x2190); Ascii = '<' }
    Restore   = @{ Emoji = (ConvertFrom-CodePoint 0x1F6DF); Symbol = (ConvertFrom-CodePoint 0x2190); Ascii = '<' }
    Revert    = @{ Emoji = (ConvertFrom-CodePoint 0x1F501); Symbol = (ConvertFrom-CodePoint 0x2194); Ascii = 'R' }
    Reflog    = @{ Emoji = (ConvertFrom-CodePoint 0x1F4DC); Symbol = (ConvertFrom-CodePoint 0x2261); Ascii = 'L' }
    Settings  = @{ Emoji = (ConvertFrom-CodePoint 0x1F527); Symbol = (ConvertFrom-CodePoint 0x263C); Ascii = '#' }
    About     = @{ Emoji = (ConvertFrom-CodePoint 0x1F4A1); Symbol = (ConvertFrom-CodePoint 0x263A); Ascii = 'i' }
    Exit      = @{ Emoji = (ConvertFrom-CodePoint 0x1F6AA); Symbol = (ConvertFrom-CodePoint 0x25C4); Ascii = '<' }
    Success   = @{ Emoji = (ConvertFrom-CodePoint 0x2705); Symbol = (ConvertFrom-CodePoint 0x221A); Ascii = '+' }
    Warning   = @{ Emoji = (ConvertFrom-CodePoint 0x1F536); Symbol = (ConvertFrom-CodePoint 0x25B2); Ascii = '!' }
    Error     = @{ Emoji = (ConvertFrom-CodePoint 0x274C); Symbol = (ConvertFrom-CodePoint 0x00D7); Ascii = 'x' }
    Info      = @{ Emoji = (ConvertFrom-CodePoint 0x1F6C8); Symbol = (ConvertFrom-CodePoint 0x263A); Ascii = 'i' }
    Yes       = @{ Emoji = (ConvertFrom-CodePoint 0x2705); Symbol = (ConvertFrom-CodePoint 0x221A); Ascii = '+' }
    No        = @{ Emoji = (ConvertFrom-CodePoint 0x274C); Symbol = (ConvertFrom-CodePoint 0x00D7); Ascii = 'x' }
    Item      = @{ Emoji = (ConvertFrom-CodePoint 0x1F539); Symbol = (ConvertFrom-CodePoint 0x2666); Ascii = '-' }
}
$script:IconColors = @{ App='Cyan'; Dashboard='Cyan'; Project='Blue'; Connect='Green'; Sync='Cyan'; Unstage='Yellow'; History='DarkCyan'; GitHub='Magenta'; Page='Blue'; Lock='Yellow'; Search='Cyan'; Command='Cyan'; Run='Green'; Form='Magenta'; Folder='Yellow'; Status='Cyan'; Initialize='Green'; Stage='Yellow'; Commit='Green'; Branch='Magenta'; Remote='Blue'; Fetch='Blue'; Pull='Blue'; Push='Green'; Undo='Yellow'; Restore='Yellow'; Revert='Red'; Reflog='DarkCyan'; Settings='Magenta'; About='Cyan'; Exit='DarkGray'; Success='Green'; Warning='Yellow'; Error='Red'; Info='Cyan'; Yes='Green'; No='Red'; Item='Cyan' }

function Get-IconTable { return $script:IconTable }
function Get-IconColor { param([Parameter(Mandatory)][string]$Name) if ($script:IconColors.ContainsKey($Name)) { return $script:IconColors[$Name] }; return 'Cyan' }

function Resolve-IconTier {
    # Pure decision logic (unit tested). $Env is a hashtable of the relevant variables.
    #   Emoji  : modern terminals (Windows Terminal, VS Code, ConEmu, UTF-8 Linux/macOS)
    #   Symbol : classic Windows console (conhost / Windows PowerShell window): single-column WGL4 glyphs
    #   Ascii  : redirected output, or forced
    # Overrides: GIT_COMMAND_MANAGER_ICONS=emoji|symbol|ascii, GIT_COMMAND_MANAGER_ASCII=1.
    param([hashtable]$Env, [bool]$IsWin, [bool]$Redirected, [bool]$Utf8Ok = $true)
    $force = ([string]$Env['GIT_COMMAND_MANAGER_ICONS']).ToLowerInvariant()
    if ($force -eq 'emoji') { return 'Emoji' }
    if ($force -eq 'symbol') { return 'Symbol' }
    if ($force -eq 'ascii') { return 'Ascii' }
    if ($force -eq 'none') { return 'None' }
    if ($Env['GIT_COMMAND_MANAGER_ASCII'] -eq '1') { return 'Ascii' }
    if ($Redirected) { return 'Ascii' }
    if (-not $IsWin) {
        if ([string]$Env['LANG'] -match 'UTF-?8' -or [string]$Env['LC_ALL'] -match 'UTF-?8') { return 'Emoji' }
        return 'Ascii'
    }
    if (-not $Utf8Ok) { return 'Ascii' }
    if ($Env['WT_SESSION'] -or $Env['TERM_PROGRAM'] -or $Env['ConEmuANSI'] -eq 'ON') { return 'Emoji' }
    return 'Symbol'
}

function Set-ConsoleUtf8Output {
    # Windows only: make the console write UTF-8 so the glyphs arrive unchanged. Also needed when output is redirected.
    if (-not (Test-IsWindows)) { return $true }
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false); return $true } catch { return $false }
}

function Get-IconTier {
    $names = 'GIT_COMMAND_MANAGER_ICONS', 'GIT_COMMAND_MANAGER_ASCII', 'LANG', 'LC_ALL', 'WT_SESSION', 'TERM_PROGRAM', 'ConEmuANSI'
    $e = @{}; foreach ($n in $names) { $e[$n] = [Environment]::GetEnvironmentVariable($n) }
    if (-not $e['GIT_COMMAND_MANAGER_ICONS'] -and $e['GIT_COMMAND_MANAGER_ASCII'] -ne '1') {
        $saved = Get-UserSetting 'icons'
        if ($saved -in @('emoji', 'symbol', 'none')) { $e['GIT_COMMAND_MANAGER_ICONS'] = $saved }   # the user's remembered choice
    }
    $redirected = $false
    try { $redirected = [Console]::IsOutputRedirected } catch { $redirected = $true }
    $win = Test-IsWindows
    $utf8 = $true
    if ($win) { $utf8 = Set-ConsoleUtf8Output }
    return (Resolve-IconTier -Env $e -IsWin $win -Redirected $redirected -Utf8Ok $utf8)
}

function Get-Icon {
    param([Parameter(Mandatory)][string]$Name, [string]$Tier = '')
    if (-not $Tier) { $Tier = $script:Tier; if (-not $Tier) { if (-not $script:DetectedTier) { $script:DetectedTier = Get-IconTier }; $Tier = $script:DetectedTier } }
    if ($Tier -eq 'None') { return '' }
    $t = Get-IconTable
    if (-not $t.ContainsKey($Name)) { $Name = 'Item' }
    return $t[$Name][$Tier]
}

function Set-IconTier { param([ValidateSet('Auto', 'Emoji', 'Symbol', 'Ascii', 'None')][string]$Tier) $script:Tier = $(if ($Tier -eq 'Auto') { '' } else { $Tier }); $script:DetectedTier = '' }
function Get-IconTierInUse { if ($script:Tier) { return $script:Tier }; if (-not $script:DetectedTier) { $script:DetectedTier = Get-IconTier }; return $script:DetectedTier }

function Set-TuiColorStyle {
    param([ValidateSet('Full','Subtle','None','Auto')][string]$Mode = 'Full',
          [ValidateSet('Cyan','Teal','Blue','Green','Purple','Yellow','Gray','White','Magenta','Red')][string]$Accent = 'Cyan')
    $script:ColorMode = $Mode; $script:Accent = $Accent
}
# Roles -> ANSI SGR codes and the legacy console color. Add a role here, never a color elsewhere.
function Get-RoleStyle {
    param([Parameter(Mandatory)][string]$Role)
    $s = @{
        Title    = @{ Ansi = '1;36'; Legacy = 'Cyan' }
        Heading  = @{ Ansi = '1;37'; Legacy = 'White' }
        Normal   = @{ Ansi = '0';    Legacy = 'Gray' }
        Dim      = @{ Ansi = '90';   Legacy = 'DarkGray' }
        Selected = @{ Ansi = '1;96'; Legacy = 'Cyan' }
        Number   = @{ Ansi = '36';   Legacy = 'Cyan' }
        Key      = @{ Ansi = '96';   Legacy = 'Cyan' }
        Success  = @{ Ansi = '32';   Legacy = 'Green' }
        Warning  = @{ Ansi = '33';   Legacy = 'Yellow' }
        Error    = @{ Ansi = '31';   Legacy = 'Red' }
        Info     = @{ Ansi = '34';   Legacy = 'Blue' }
    }
    $acc = @{ Cyan = '36'; Teal = '36'; Blue = '34'; Green = '32'; Purple = '35'; Yellow = '33'; Gray = '37'; White = '37'; Magenta = '35'; Red = '31' }
    $legacy = @{ Cyan = 'Cyan'; Teal = 'Cyan'; Blue = 'Blue'; Green = 'Green'; Purple = 'Magenta'; Yellow = 'Yellow'; Gray = 'Gray'; White = 'White'; Magenta = 'Magenta'; Red = 'Red' }
    if ($Role -eq 'Description') { return @{ Ansi = '2;37;48;5;236'; Legacy = 'DarkGray' } }
    if ($script:ColorMode -eq 'None' -or $env:NO_COLOR) {
        return @{ Ansi = '0'; Legacy = $(if ($Role -eq 'Selected') { 'White' } else { 'Gray' }) }
    }
    if ($Role -in @('Title','Selected','Number','Key')) {
        $shade = $(if ($script:ColorMode -eq 'Subtle') { '0;' } else { '1;' })
        return @{ Ansi = ($shade + $acc[$script:Accent]); Legacy = $legacy[$script:Accent] }
    }
    if ($s.ContainsKey($Role)) { return $s[$Role] }
    return $s['Normal']
}

Export-ModuleMember -Function Get-IconTable, Get-IconColor, Resolve-IconTier, Set-ConsoleUtf8Output, Get-IconTier, Get-Icon, Set-IconTier, Get-IconTierInUse, Set-TuiColorStyle, Get-RoleStyle
