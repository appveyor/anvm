@{
    RootModule        = 'anvm.psm1'
    ModuleVersion     = '7.7.7'
    GUID              = '32c3b362-dfe9-4630-aa03-cff79ba1cbbb'
    Author            = 'Appveyor Systems Inc.'
    CompanyName       = 'Appveyor Systems Inc.'
    Copyright         = 'Copyright (c) 2021-2022 Appveyor Systems Inc. All rights reserved.'
    Description       = 'AppVeyor Node.js Version Manager'
    PowerShellVersion = '5.0'
    NestedModules     = @()
    FunctionsToExport = @(
        'Install-NodeVersion',
        'Set-NodeVersion'
        )
    CmdletsToExport   = '*'
    VariablesToExport = '*'
    AliasesToExport   = '*'
    PrivateData       = @{
        PSData = @{
            #Tags = @()
            LicenseUri = 'https://github.com/appveyor/nvm/blob/main/LICENSE'
            ProjectUri = 'https://github.com/appveyor/nvm'
    
            # ReleaseNotes of this module
            # ReleaseNotes = ''
    
            # Prerelease string of this module
            # Prerelease = 'beta'
        }
    } # End of PrivateData hashtable
    # HelpInfoURI = ''
    # DefaultCommandPrefix = ''
}