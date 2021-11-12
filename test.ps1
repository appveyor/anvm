$ErrorActionPreference = 'Stop'

# re-load module
Clear-Host
Remove-Module anvm -Force -ErrorAction SilentlyContinue
Import-Module -Force .\src\anvm.psm1

# run cmdlet
# Install-NodeVersion 6.11
# Install-NodeVersion 0.10
# Install-NodeVersion 3
# Install-NodeVersion 4.4.0
# Install-NodeVersion 4.5
# Install-NodeVersion 4
# Install-NodeVersion 5.9
# Install-NodeVersion 6.2
# Install-NodeVersion 6.11 x86
# Install-NodeVersion 10 x86
# Install-NodeVersion 16
# Install-NodeVersion 17
# Install-NodeVersion lts x86
# Install-NodeVersion current x64
Set-NodeVersion 12 x64