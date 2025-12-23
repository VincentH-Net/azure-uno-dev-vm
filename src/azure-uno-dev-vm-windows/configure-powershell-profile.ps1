Set-StrictMode -Version Latest

# 1. Choose which profile you want to edit.
#    $PROFILE is "CurrentUserCurrentHost" by default.
#    Other options:
#      $PROFILE.CurrentUserAllHosts
#      $PROFILE.AllUsersAllHosts
$profilePath = $PROFILE
Write-Host ''
Write-Host "Using profile: $profilePath"

# Ensure the directory and file exist
$profileDir = Split-Path -Path $profilePath -Parent
if (-not (Test-Path -Path $profileDir)) {
    Write-Host "Creating profile directory: $profileDir"
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

if (-not (Test-Path -Path $profilePath)) {
    Write-Host "Creating profile file: $profilePath"
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

function Set-SnippetInProfile {
    param (
        [string]$Name,
        [string]$Snippet,
        [string]$Marker
    )

    $alreadyThere = $false
    if (Test-Path $profilePath) {
        $alreadyThere = Select-String -Path $profilePath -Pattern $Marker -SimpleMatch -Quiet
    }

    if (-not $alreadyThere) {
        Write-Host "Appending $Name to profile..."
        Add-Content -Path $profilePath -Value "`n$Snippet`n"
    } else {
        Write-Host "$Name already present in profile; skipping append."
    }
}

$snippet = @'
# Enable .NET 10 CLI tab completion
dotnet completions script pwsh | Out-String | Invoke-Expression
'@
Set-SnippetInProfile -Name ".NET 10 CLI tab completion" -Snippet $snippet -Marker 'dotnet completions script'

$snippet = @'
# Enable AZ tab completion
Write-Output "Enabling AZ tab completion..."
Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    $env:_ARGCOMPLETE_SHELL = 'powershell'
    az 2>&1 | Out-Null
    Get-Content $completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}

Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
'@
Set-SnippetInProfile -Name "AZ tab completion" -Snippet $snippet -Marker 'Register-ArgumentCompleter -Native -CommandName az'

$dstDir = Join-Path $env:ProgramData 'oh-my-posh'
$dst = Join-Path $dstDir 'atomic-min-dotnet-git-az.omp.json'
if (-not (Test-Path $dst)) {
    $src = Join-Path $PSScriptRoot 'atomic-min-dotnet-git-az.omp.json'
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
}
$snippet = @"
# Enable Oh-My-Posh enhanced PowerShell prompt
oh-my-posh init pwsh --config '$dst' | Invoke-Expression
"@
Set-SnippetInProfile -Name "Oh-My-Posh enhanced PowerShell prompt" -Snippet $snippet -Marker 'oh-my-posh'

$snippet = @'
Import-Module -Name Terminal-Icons
'@
Set-SnippetInProfile -Name "Terminal-Icons module import" -Snippet $snippet -Marker 'Terminal-Icons'
