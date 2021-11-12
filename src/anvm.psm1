$nvmPath = "$env:APPDATA\anvm"
$sevenZipAvailable = $false
if (Get-Command "7z" -ErrorAction SilentlyContinue) {
    $sevenZipAvailable = $true
}
$node64Path = "$env:ProgramFiles\nodejs"
$node32Path = "${env:ProgramFiles(x86)}\nodejs"
$npmPath = "$env:APPDATA\npm"
$global:node_versions = @()

function Install-NodeVersion {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$version,
        [Parameter(Mandatory=$false, Position=1)]
        [ValidateSet('x64', 'x86')]
        [string]$arch
    )

    if (-not $arch) {
        $arch = 'x64'
    }

    $version = getNodeVersion $version

    $v = parseVersion $version
    if ($v.Major -ge 1 -and $v.Major -lt 4) {
        $baseUrl = "https://iojs.org/dist/v$version"
        $productName = "iojs"
    } else {
        $baseUrl = "https://nodejs.org/dist/v$version"
        $productName = "node"
    }

    Write-Host "Installing Node v$version $arch..." -NoNewline

    $nodePath = getNodePath $version $arch
    if (Test-Path $nodePath) {
        Write-Host "already installed"
    } else {
        $origProg = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        $fileName = "$productName-v$version-win-$arch.7z"
        try {
            $packageUrl = "$baseUrl/$fileName"
            Invoke-WebRequest -Uri $packageUrl -OutFile "$env:TEMP\$fileName" -UseBasicParsing
        } catch {
            $fileName = "$productName-v$version-$arch.msi"
            $packageUrl = "$baseUrl/$fileName"
            try {
                Invoke-WebRequest -Uri $packageUrl -OutFile "$env:TEMP\$fileName" -UseBasicParsing
            } catch {
                $packageUrl = "$baseUrl/x64/$fileName"
                try {
                    Invoke-WebRequest -Uri $packageUrl -OutFile "$env:TEMP\$fileName" -UseBasicParsing
                } catch {
                    throw "Package not found!"
                }
            }
        } finally {
            $ProgressPreference = $origProg
        }

        if ($fileName.EndsWith(".msi")) {
            installNodeMsi $version $arch "$env:TEMP\$fileName"
        } else {
            unzip $version $arch "$env:TEMP\$fileName"
        }

        Write-Host "OK"
    }
}

function Set-NodeVersion {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$version,
        [Parameter(Mandatory=$false, Position=1)]
        [ValidateSet('x64', 'x86')]
        [string]$arch
    )

    ensureElevatedModeOnWindows "Switching Node version requires elevated mode."

    if (-not $arch) {
        $arch = 'x64'
    }

    $version = getNodeVersion $version

    $nodePath = getNodePath $version $arch
    if (-not (Test-Path $nodePath)) {
        Install-NodeVersion $version $arch
    }
    
    Write-Host "Using Node v$version $arch"

    if (Test-Path $node64Path) {
        (Get-Item $node64Path).Delete()
    }
    if (Test-Path $node32Path) {
        (Get-Item $node32Path).Delete()
    }

    if ($arch -eq 'x64') {
        New-Item -ItemType SymbolicLink -Path $node64Path -Target $nodePath | Out-Null
    } else {
        New-Item -ItemType SymbolicLink -Path $node32Path -Target $nodePath | Out-Null
    }

    addPath $node64Path
    addPath $node32Path
    addPath $npmPath
    addSessionPath $node64Path
    addSessionPath $node32Path
    addSessionPath $npmPath 
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

    for($i = 0; $i -lt $versionDigits.Length; $i++) {
        $version.number += [long]$versionDigits[$i] -shl 16 * (3 - $i)
    }

    return $version
}

function getNodeVersion([string]$partialVersion) {
    if ($global:node_versions.Length -eq 0) {
        $global:node_versions = (Invoke-WebRequest -Uri 'https://nodejs.org/dist/index.json' -UseBasicParsing).Content | ConvertFrom-Json
        $global:node_versions += (Invoke-WebRequest -Uri 'https://iojs.org/dist/index.json' -UseBasicParsing).Content | ConvertFrom-Json
    }

    if ($partialVersion -eq 'lts' -or $partialVersion -eq 'stable') {
        foreach($ver in $global:node_versions) {
            if ($ver.lts) {
                return $ver.version.substring(1)
            }
        }
    } elseif ($partialVersion -eq 'current' -or $partialVersion -eq 'latest') {
        return $global:node_versions[0].version.substring(1)
    } else {
        $v = parseVersion $partialVersion
        if ($v.major -ne -1 -and $v.minor -ne -1 -and $v.build -ne -1) {
            return $partialVersion
        } else {
            $prefix = $partialVersion.Trim(".") + "."
            $latestVersion = $null
            foreach($ver in $global:node_versions) {
                $vj = $ver.version.substring(1)
                if ($vj.startswith($prefix)) {
                    if ($null -eq $latestVersion -or (parseVersion $vj).number -gt (parseVersion $latestVersion).number) {
                        $latestVersion = $vj
                    }
                }
            }
            if ($null -eq $latestVersion) {
                throw "Node v$partialVersion not found"
            }
            return $latestVersion
        }
    }
}

function unzip([string]$version, [string]$arch, [string]$zipfile)
{
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

    $tempDir = "$env:TEMP\anvm-$version-$arch"
    ensureElevatedModeOnWindows "Installing Node from MSI requires elevated mode."
    $destDir = getNodePath $version $arch
    $msiArgs = @("/i", "`"$msiFile`"", "/q", "ADDLOCAL=$features", "INSTALLDIR=`"$tempDir`""<#, "/L*V", "C:\Projects\2\node-install.log"#>)

    $result = Start-Process -FilePath "msiexec.exe" -Wait -PassThru -ArgumentList $msiArgs
    if ($result.ExitCode -ne 0) {
        throw "msiexec installing node.msi exited with $($result.ExitCode)"
    }

    # copy installation
    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
    Get-ChildItem -Path $tempDir | Copy-Item -Destination $destDir -Force -Recurse

    # uninstall node
    uninstallNode
}

function uninstallNode() {
    $uninstallCommand = getUninstallString "Node.js"

    if ($uninstallCommand) {
        Write-Verbose "Uninstalling existing installation of Node.js ..."
        ensureElevatedModeOnWindows "Uninstalling Node requires elevated mode."

        $uninstallCommand = $uninstallCommand.replace('MsiExec.exe /I{', '/x{').replace('MsiExec.exe /X{', '/x{')
        cmd /c start /wait msiexec.exe $uninstallCommand /quiet

        Write-Verbose "Uninstalled Node.js"
    } else {
        Write-Verbose "Node.js is not installed"
    }
}

function getUninstallString($productName) {
    $x64items = @(Get-ChildItem "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")
    ($x64items + @(Get-ChildItem "HKLM:SOFTWARE\wow6432node\Microsoft\Windows\CurrentVersion\Uninstall") `
        | ForEach-object { Get-ItemProperty Microsoft.PowerShell.Core\Registry::$_ } `
        | Where-Object { $_.DisplayName -and $_.DisplayName.Contains($productName) } `
        | Select-Object UninstallString).UninstallString
}

function ensureElevatedModeOnWindows([string]$msg) {
    if (-not $isLinux -and -not $isMacOS -and -not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        throw $msg
    }
}

function getSanitizedPath([string]$path) {
    return $path.Replace('/', '\').Trim('\').Trim(' ')
}

function addPath([string]$path) {

    $sanitizedPath = getSanitizedPath $path
    $machinePath = [Environment]::GetEnvironmentVariable("path", "machine")

    foreach($item in $machinePath.Split(";")) {
        if($sanitizedPath -eq (getSanitizedPath $item)) {
            return # already added
        }
    }

    [Environment]::SetEnvironmentVariable("path", "$sanitizedPath;$machinePath", "machine")
}

function addSessionPath([string]$path) {

    $sanitizedPath = getSanitizedPath $path

    foreach($item in $env:path.Split(";")) {
        if($sanitizedPath -eq (getSanitizedPath $item)) {
            return # already added
        }
    }

    $env:path = "$sanitizedPath;$env:path"
}