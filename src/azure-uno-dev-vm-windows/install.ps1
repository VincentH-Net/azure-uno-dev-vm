Set-StrictMode -Version Latest

# Ensure elevated administrator mode

$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if (-not $IsAdmin) {
    Write-Error "This script must be run as Administrator. Right-click Start Menu and choose 'Terminal (admin)', then run this script again."
    exit 1
}

# ---------------------------------------------
# Ensure PowerShell 7+ (install & relaunch if needed)
# ---------------------------------------------

function Get-PwshPath {
    # 1) Try if it's already in PATH
    $cmd = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    # 2) Look in typical installation locations regardless of PATH
    $candidateRoots = @(
        "$env:ProgramFiles\PowerShell",
        "$env:ProgramFiles(x86)\PowerShell"
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($root in $candidateRoots) {
        $pwsh = Get-ChildItem -Path $root -Filter pwsh.exe -Recurse -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending |
                Select-Object -First 1

        if ($pwsh) {
            return $pwsh.FullName
        }
    }

    return $null
}

function Install-WingetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Id,
        [string] $override,
        [string] $scope = 'machine'
    )

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "winget.exe not found. Cannot install package $Id."
    }

    # Idempotent: skip if already installed
    $installed = winget list --id $Id --source winget --accept-source-agreements 2>$null
    if (($installed -join ' ') -match " $Id ") {
        Write-Host "`n$Id already installed, skipping."
        $global:LASTEXITCODE = $null
        return
    }

    $arguments = @(
        'install',
        '--id', $Id,
        '--source', 'winget',
        '--scope', $scope,
        '--accept-source-agreements',
        '--accept-package-agreements',
        '-h'
    )

    if ($override) {
        $arguments += @('--override', $override)
    }

    Write-Host "`nInstalling $Id $override ($scope scope)..."
    & $winget.Path @arguments 2>&1

    return
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Current PowerShell version is $($PSVersionTable.PSVersion). PowerShell 7+ is required."

    $pwshPath = Get-PwshPath

    if (-not $pwshPath) {
        Write-Host "PowerShell 7 (pwsh.exe) not found, attempting installation via winget..."

        # Install PowerShell 7 for all users (machine scope)
        Install-WingetPackage -Id 'Microsoft.PowerShell'

        # After install, do NOT rely on PATH; search known locations instead
        $pwshPath = Get-PwshPath
        if (-not $pwshPath) {
            Write-Error "PowerShell 7 installation appears to have failed: pwsh.exe still not found in known locations."
            exit 1
        }
    }

    # We need the current script path to re-run it
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        Write-Error "Cannot determine script path (`\$PSCommandPath` is empty). Cannot relaunch under PowerShell 7."
        exit 1
    }

    # Reconstruct argument list: bound parameters + unbound arguments
    $argList = @()

    $paramMetadata = $MyInvocation.MyCommand.Parameters

    foreach ($kvp in $PSBoundParameters.GetEnumerator()) {
        $name  = $kvp.Key
        $value = $kvp.Value
        $paramInfo = $paramMetadata[$name]

        if ($paramInfo -and $paramInfo.ParameterType -eq [switch]) {
            if ($value) {
                $argList += "-$name"
            }
        }
        else {
            $argList += "-$name"
            $argList += "$value"
        }
    }

    if ($args.Count -gt 0) {
        $argList += $args
    }

    $finalArgs = @(
        '-File', $scriptPath
    ) + $argList

    Write-Host "Re-launching script in PowerShell 7:"
    Write-Host "`"$pwshPath`" $($finalArgs -join ' ')"

    & $pwshPath $finalArgs
    exit
}

# --- From this point onward, you are guaranteed to be in PowerShell 7+ ---

$global:RebootNeeded = $false

function Request-ManualReboot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $componentName,

        [bool] $scriptCompleted = $false
    )

    $msg = "`nReboot to complete $componentName install"
    if (-not $scriptCompleted) {
        $msg = $msg + " and then run this script again to continue"
    }

    Write-Host $msg
    exit
}

# ---------------------------------------------
# Expand a partition to use all free space on its disk
# ---------------------------------------------
function Expand-PartitionToMax {
    [CmdletBinding()]
    param(
        # Drive letter of the volume to expand, e.g. 'C'
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Z]$')]
        [char] $DriveLetter
    )

    Write-Host "`nExpanding partition for drive $DriveLetter`: if possible..."

    try {
        # Storage module provides Get-Partition, Get-PartitionSupportedSize, Resize-Partition
        Import-Module Storage -ErrorAction Stop

        # Get the partition for the specified drive
        $partition = Get-Partition -DriveLetter $DriveLetter -ErrorAction Stop

        # Determine the supported min/max size
        $supported = Get-PartitionSupportedSize -DiskNumber $partition.DiskNumber `
                                                -PartitionNumber $partition.PartitionNumber `
                                                -ErrorAction Stop

        if ($partition.Size -ge $supported.SizeMax) {
            Write-Host "Partition for drive $DriveLetter`: already at maximum size. skipping."
            return
        }

        Write-Host ("Current size : {0:N0} GB" -f ($partition.Size / 1GB))
        Write-Host ("Max size     : {0:N0} GB" -f ($supported.SizeMax / 1GB))
        Write-Host "Resizing partition to maximum supported size..."

        Resize-Partition -DiskNumber $partition.DiskNumber `
                         -PartitionNumber $partition.PartitionNumber `
                         -Size $supported.SizeMax `
                         -ErrorAction Stop

        Write-Host "Partition for drive $DriveLetter`: successfully expanded."
    }
    catch {
        Write-Error "Failed to expand partition for drive $DriveLetter`: $($_.Exception.Message)"
        throw
    }
}

function Install-WSL2 {
    [CmdletBinding()]
    param()

    $wslCmd = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wslCmd) {
        $output   = & $wslCmd.Source --status 2>&1
        if ('Default Version: 2' -in $output) {
            Write-Host "`nWSL is already installed with version 2 as the default, skipping"
            return
        }
    }

    Write-Host "`nWSL 2 not installed or version 2 is not the default. Running 'wsl --install' and setting default version to 2..."
    & wsl.exe --install --no-distribution
    & wsl.exe --set-default-version 2

    $global:RebootNeeded = $true
    # WSL 2 needs a reboot to complete, but no need to ask the user to do that now - can be any time later in or after this script
}

function Install-DockerDesktop {
    [CmdletBinding()]
    param()

    # Docker Desktop package id in winget
    $dockerId = "Docker.DockerDesktop"

    Install-WingetPackage -Id $dockerId

    # Optional: lightweight check that it's installed
    $dockerExe = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerExe) {
        Write-Host "Docker CLI detected at $($dockerExe.Source)"
    }
    else {
        Write-Warning "Docker Desktop installed but docker.exe not yet on PATH for this session. Open a new terminal session if you need Docker on PATH."
        #TODO: do we need this test for Aspire?
    }
}

function Install-Aspire {
    [CmdletBinding()]
    param()

    $aspire = Get-Command aspire -ErrorAction SilentlyContinue

    if ($aspire) {
        Write-Host "`nAspire CLI already installed at $($aspire.Path), skipping."
    }
    else {
        Write-Host "`nAspire CLI not found, installing..."
        Invoke-RestMethod https://aspire.dev/install.ps1 | Invoke-Expression
    }
}

function Install-VisualStudioWithWorkloads {
    [CmdletBinding()]
    param()
    
    $vsId = "Microsoft.VisualStudio.Enterprise"
    $vsConfigFilePath = Join-Path $PSScriptRoot '.vsconfig'

    $vsOverride = @(
        "--quiet",
        "--nocache",
        "--norestart"
        "--wait"
        "--config $vsConfigFilePath"
    ) -join " "

    Install-WingetPackage -Id $vsId -override $vsOverride
    $exitCode = $LASTEXITCODE
    if ($null -ne $exitCode) {
        Write-Host "$vsId install finished with exit code $exitCode"
    }
    switch ($exitCode) {
        $null      {             # was already installed, skipped
            return
        }
        0      {                 # success, should mean no reboot required but we see the installer displaying that a rebvoot is needed, so... reboot always
            Request-ManualReboot -componentName $vsId
        }
        3010   {                 # success, reboot required
            Request-ManualReboot -componentName $vsId
        }
        1641   {                 # success + reboot initiated
            Write-Host "Install of $vsId succeeded; reboot initiated. After reboot run this script again to continue"
            exit
        }
        default {
            throw "winget install for $vsId failed with exit code $exitCode."
        }
    }
}

function Install-VSCodeExtensionsFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ExtensionsFile
    )

    if (-not (Test-Path $ExtensionsFile)) {
        throw "Extensions file not found: $ExtensionsFile"
    }

    Write-Host ""

    # Make sure code CLI is available
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if (-not $codeCmd) {
        Write-Host "VS Code CLI ('code') not found in PATH. Open a new terminal session to use the lastest PATH and run this script again to continue."
        exit
    }

    # Read desired extensions, ignore empty lines and comments starting with '#'
    $extensions = Get-Content $ExtensionsFile |
        Where-Object { $_ -and (-not $_.StartsWith('#')) } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' }

    # Get currently installed extensions (IDs only)
    $installed = & $codeCmd.Path --list-extensions 2>$null

    foreach ($ext in $extensions) {
        if ($installed -contains $ext) {
            Write-Host "VS Code extension already installed: $ext, skipping."
            continue
        }

        Write-Host "Installing VS Code extension: $ext"
        & $codeCmd.Path --install-extension $ext
    }
}

function Install-AndroidSdkLicenses {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SdkRoot
    )

    if ($null -eq $env:JAVA_HOME)
    {
        Write-Host "`nJAVA_HOME environment var is not set in this terminal session. Open a new terminal session window and there run this script again to continue"
        exit
    }

    $sdkManager = Join-Path $SdkRoot 'cmdline-tools\latest\bin\sdkmanager.bat'
    if (-not (Test-Path $sdkManager)) {
        throw "sdkmanager.bat not found at '$sdkManager'. Check your SDK install."
    }

    Write-Host "`nAccepting Android SDK licenses using: $sdkManager"

    # Local 'yes' helper: writes endless 'y' lines to the pipeline
    function yes {
        param([string] $Text = 'y')
        for ($i = 0; $i -lt 50; $i++) { $Text }
    }

    # Stream 'y' into sdkmanager --licenses; sdkmanager will exit when done
    yes | & $sdkManager --licenses
}

function Install-TerminalIcons {
    [CmdletBinding()]
    param()

    $mod = Get-Module -Name Terminal-Icons
    if ($mod) {
        Write-Host "`nTerminal-Icons already installed; skipping."
        return
    }

    $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($repo -and $repo.InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
    Write-Host "`nInstallling module Terminal-Icons"
    Install-Module -Name Terminal-Icons -Repository PSGallery
}

# ---------------------------------------------
# Ensure OS drive uses all available space
# ---------------------------------------------
# $env:SystemDrive is usually 'C:'
$sysDriveLetter = $env:SystemDrive.TrimEnd(':')
Expand-PartitionToMax -DriveLetter $sysDriveLetter

# Ensure WSL2 features are ready for Docker Desktop - no distribution installed
Install-WSL2
# If you need to reboot the script will stop here.
# On the next run it will see WSL 2 already enabled and just continue.

# Ensure Docker Desktop is installed (machine-wide) - it will use the WSL 2 engine
Install-DockerDesktop

# Azure CLI
Install-WingetPackage 'Microsoft.AzureCLI'

# Git for Windows incl Git Credential Manager
Install-WingetPackage 'Git.Git'

# Azure Storage Explorer 
Install-WingetPackage 'Microsoft.Azure.StorageExplorer'

# Aspire CLI
Install-Aspire

# Visual Studio Enterprise 2026 with required workloads and extensions
Install-VisualStudioWithWorkloads

# Visual Studio Code with extensions
Install-WingetPackage 'Microsoft.VisualStudioCode'

# Visual Studio Code extensions
Install-VSCodeExtensionsFromFile -ExtensionsFile (Join-Path $PSScriptRoot 'vscode-extensions.txt')

# Uno.Check
dotnet tool install -g Uno.Check
# Above causes a message to be desplayed to execute below, interactive dev-certs step.
# Uno-check skips this in non-interactive mode, so we do it interactively here - it will cause a dialog popup
dotnet dev-certs https --trust

# Uno.Check fix all
uno-check --non-interactive --target wasm --target ios --target android --target desktop --fix

# Accept Android SDK licenses in admin elevated console: 
Install-AndroidSdkLicenses -SdkRoot "C:\Program Files (x86)\Android\android-sdk"

# Oh-My_POSH powershell prompt
Install-WingetPackage 'JanDeDobbeleer.OhMyPosh' -scope 'user'
if ($null -ne $global:LASTEXITCODE) {
    oh-my-posh font install CascadiaMono
    $global:RebootNeeded = true # Font install needs a restart before VS and VS Code can see it
}

Install-TerminalIcons

# PowerShell profile configuration
& (Join-Path $PSScriptRoot 'configure-powershell-profile.ps1')

Write-Host ''
Write-Host 'Development machine install completed.'
Write-Host ''
Write-Host 'To configure Windows Terminal font to display icons:'
Write-Host '1) Open Settings in Windows Terminal'
Write-Host '2) In the "Startup" tab, for "Default profile" select "PowerShell" to use PowerShell 7 by default'
Write-Host '3) In the "Profiles / Defaults" tab, select "Appearance", set the "Font Face" to "CaskaydiaMono Nerd Font Mono" and then "Save"'
Write-Host '   This will make icons in the PowerShell prompt display correctly'
Write-Host ''
Write-Host 'To configure VS Code font to display icons and code ligatures:'
Write-Host '1) Open Settings in VS Code'
Write-Host '2) Set the "Editor: Font Family" to "Cascadia Code"'
Write-Host '   In the "Editor: Font Ligatures" set "editor.fontLigatures": true'
Write-Host '   This will make the editor display ligatures'
Write-Host '3) Set the "Terminal > Integrated: Font Family" to "CaskaydiaMono NFM"'
Write-Host '   This will make icons in the PowerShell prompt in the VS Code built-in terminal display correctly'
Write-Host '4) Close and reopen VS Code to apply the changes'
Write-Host ''
Write-Host 'To configure Visual Studio font to display icons and code ligatures:'
Write-Host '1) Open "Options" in Visual Studio'
Write-Host '2) In "Environment" | "Fonts and Colors":'
Write-Host '   - For "Editor", set "Font" to "Cascadia Code"'
Write-Host '     This will make the editor display ligatures'
Write-Host '   - For "Terminal", set "Font" to "CaskaydiaMono NFM"'
Write-Host '     This will make icons in the PowerShell prompt in the Visual Studio built-in terminal display correctly'
Write-Host ''
Write-Host 'NJoy developing!'

if ($global:RebootNeeded)
{
    Request-ManualReboot -componentName "machine" -scriptCompleted $true
}
