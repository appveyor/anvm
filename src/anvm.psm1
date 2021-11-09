$nvmPath = "$env:APPDATA\anvm"
$sevenZipAvailable = $false
if (Get-Command "7z" -ErrorAction SilentlyContinue) {
    $sevenZipAvailable = $true
}
$node64Path = "$env:ProgramFiles\nodejs"
$node32Path = "${env:ProgramFiles(x86)}\nodejs"

function Install-NodeVersion {
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromRemainingArguments=$true)]
        [string]$version
    )
    
    Write-Host "Installing Node $version"
    Write-Host "7z available: $sevenZipAvailable"

    #$destPath = getNodePath("1.0.0", "x64")
    #unzip "17.0.1" "x64" "C:\Users\feodo\Downloads\node-v17.0.1-win-x64.7z"
    #installNodeMsi "15.14.0" "x64" ""C:\Users\feodo\Downloads\node-v15.14.0-x64.msi""
    #getUninstallString "Node.js"
    uninstallNode

    # 1. Get the exact version of Node
    # 2. Download and unpack/install Node version
}

function Set-NodeVersion {
    param(
        [Parameter(Mandatory=$true, Position=0, ValueFromRemainingArguments=$true)]
        [string]$version
    )
    
    Write-Host "Use Node $version"

    #New-Item -ItemType Directory -Force -Path $nvmPath

    # 1. Call "Install-NodeVersion" to ensure required version installed
    # 2. Delete both 32- and 64-bit Node symlinks
    # 3. Create symlink to a required version
    # 4. Modify PATH variable in session and on machine level:
    #      - path to $node64Path, $node64Path and $env:APPDATA\npm
}

function getNodePath($version, $arch) {
    $p1 = Join-Path $nvmPath $version
    if ($arch) {
        $p1 = Join-Path $p1 $arch
    }
    return $p1
}

function parseVersion([string]$str) {
    $versionDigits = $str.Split('.')
    $version = @{
        major = -1
        minor = -1
        build = -1
        revision = -1
        number = 0
        value = $null
    }

    $version.value = $str

    if($versionDigits -and $versionDigits.Length -gt 0) {
        $version.major = [int]$versionDigits[0]
    }
    if($versionDigits.Length -gt 1) {
        $version.minor = [int]$versionDigits[1]
    }
    if($versionDigits.Length -gt 2) {
        $version.build = [int]$versionDigits[2]
    }
    if($versionDigits.Length -gt 3) {
        $version.revision = [int]$versionDigits[3]
    }

    for($i = 0; $i -lt $versionDigits.Length; $i++) {
        $version.number += [long]$versionDigits[$i] -shl 16 * (3 - $i)
    }

    return $version
}

function getNodeVersion([string]$partialVersion) {
    # TODO
    # Supported aliases:
    # - lts/stable
    # - current/latest
    # Use https://nodejs.org/dist/index.json
}

function unzip([string]$version, [string]$arch, [string]$zipfile)
{
    Write-Host "Unpacking Node v$version $arch..."

    # unpack to a temp dir
    $tempPath = "$env:TEMP\anvm-$version-$arch"
    if ($sevenZipAvailable) {
        7z x $zipfile -y -o"$tempPath" | Out-Null
    } else {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $tempPath)
    }

    # move to a final destination
    $srcDir = (Get-ChildItem -Path $tempPath -Force -Directory | Select-Object -First 1).FullName
    $versionDir = getNodePath $version
    $destDir = getNodePath $version $arch
    New-Item -Path $versionDir -ItemType Directory -Force | Out-Null
    [IO.Directory]::Move($srcDir, $destDir)
    Remove-Item $tempPath -Recurse -Force
}

function installNodeMsi([string]$version, [string]$arch, [string]$msiFile) {
    $v = parseVersion $version
    if ($v.Major -eq 0 -or $v.Major -ge 4) {
        $features = 'NodeRuntime,npm'
    } else {
        $features = 'NodeRuntime,NodeAlias,npm' 
    }

    Write-Host "Installing Node v$version $arch..."
    ensureElevatedModeOnWindows "Installing Node from MSI requires elevated mode."
    $destDir = getNodePath $version $arch
    $msiArgs = @("/i", "`"$msiFile`"", "/q", "ADDLOCAL=$features", "INSTALLDIR=`"$destDir`"", "/L*V", "C:\Projects\2\example.log")

    $result = Start-Process -FilePath "msiexec.exe" -Wait -PassThru -ArgumentList $msiArgs
    if ($result.ExitCode -ne 0) {
        throw "msiexec installing node.msi exited with $($result.ExitCode)"
    }
}

function uninstallNode() {
    $uninstallCommand = getUninstallString "Node.js"

    if ($uninstallCommand) {
        Write-Host "Uninstalling existing installation of Node.js ..."
        ensureElevatedModeOnWindows "Uninstalling Node requires elevated mode."

        $uninstallCommand = $uninstallCommand.replace('MsiExec.exe /I{', '/x{').replace('MsiExec.exe /X{', '/x{')
        cmd /c start /wait msiexec.exe $uninstallCommand /quiet

        Write-Host "Uninstalled Node.js"
    } else {
        Write-Host "Node.js is not installed"
    }
}

function getUninstallString($productName) {
    $x64items = @(Get-ChildItem "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")
    ($x64items + @(Get-ChildItem "HKLM:SOFTWARE\wow6432node\Microsoft\Windows\CurrentVersion\Uninstall") `
        | ForEach-object { Get-ItemProperty Microsoft.PowerShell.Core\Registry::$_ } `
        | Where-Object { $_.DisplayName -and $_.DisplayName.Contains($productName) } `
        | Select-Object UninstallString).UninstallString
}

# if ($uninstallCommand) {
#     Write-Host "Uninstalling existing installation of CosmosDB Emulator ..." -ForegroundColor Cyan

#     $uninstallCommand = $uninstallCommand.replace('MsiExec.exe /I{', '/x{').replace('MsiExec.exe /X{', '/x{')
#     cmd /c start /wait msiexec.exe $uninstallCommand /quiet

#     Write-Host "Uninstalled $name" -ForegroundColor Green
# }

function ensureElevatedModeOnWindows([string]$msg) {
    if (-not $isLinux -and -not $isMacOS -and -not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        throw $msg
    }
}