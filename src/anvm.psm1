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

    getNodePath("1.0.0", "x64")

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
    return [IO.Path]::Join($nvmPath, $version, $arch)
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

function unzip([string]$version, [string]$arch, [string]$zipfile, [string]$destDir)
{
    Write-Host "Unpacking Node v$version $arch..."
    if ($sevenZipAvailable) {
        7z x $zipfile -y -o"$destDir" | Out-Null
    } else {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $destDir)
    }
}

function installNodeMsi([string]$version, [string]$arch, [string]$msiFile, [string]$destDir) {
    $v = parseVersion $version
    if ($v.Major -eq 0 -or $v.Major -ge 4) {
        $features = 'NodeRuntime,npm'
    } else {
        $features = 'NodeRuntime,NodeAlias,npm' 
    }

    Write-Host "Installing Node v$version $arch..."
    cmd /c start /wait msiexec /i "$msiFile" /q "ADDLOCAL=$features" "TARGETDIR=`"$destDir`""
}