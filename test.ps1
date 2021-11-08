# re-load module
Clear-Host
Remove-Module anvm -Force -ErrorAction SilentlyContinue
Import-Module -Force .\src\anvm.psm1

# run cmdlet
Install-NodeVersion 6
Set-NodeVersion 6