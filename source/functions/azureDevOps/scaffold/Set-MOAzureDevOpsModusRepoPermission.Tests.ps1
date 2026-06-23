BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    $dependencies = @(
        'Get-AuthHeader.ps1'
        'Invoke-AdoRest.ps1'
        'Get-AdoResource.ps1'
    )
    $dependencies.ForEach{
        if ($sourceMap.ContainsKey($_)) { . $sourceMap[$_] }
        else { Write-Warning "Dependency not found under source: $_" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Set-MOAzureDevOpsModusRepoPermission'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Set-MOAzureDevOpsModusRepoPermission' {
    BeforeAll {
        $cred = [pscredential]::new('pat', (ConvertTo-SecureString 'secret-pat' -AsPlainText -Force))
    }

    BeforeEach {
        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        # Both the project and the repository resolve to an id.
        Mock Get-AdoResource { [pscustomobject]@{ id = 'guid-1' } }

        # Identity search (GET) - resolves the build-service identity.
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/identities' } -MockWith {
            [pscustomobject]@{ value = @([pscustomobject]@{ descriptor = 'Microsoft.TeamFoundation.Identity;S-1-9-1' }) }
        }
        # The ACL grant (POST).
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/accesscontrolentries/' -and $Method -eq 'Post' } -MockWith {
            [pscustomobject]@{ count = 1 }
        }
    }

    It 'grants the permission when project, repo and identity all resolve' {
        Set-MOAzureDevOpsModusRepoPermission -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates
        Should -Invoke Invoke-AdoRest -Times 1 -ParameterFilter { $Uri -match '/accesscontrolentries/' -and $Method -eq 'Post' }
    }

    It 'throws when the identity cannot be resolved' {
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/identities' } -MockWith { [pscustomobject]@{ value = @() } }
        { Set-MOAzureDevOpsModusRepoPermission -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates } |
            Should -Throw '*Identity*not found*'
    }

    It 'throws when the project does not exist' {
        Mock Get-AdoResource -ParameterFilter { $Uri -match '/projects/' } -MockWith { $null }
        { Set-MOAzureDevOpsModusRepoPermission -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates } |
            Should -Throw '*Project*not found*'
    }

    It 'throws when the repository does not exist' {
        Mock Get-AdoResource -ParameterFilter { $Uri -match '/git/repositories/' } -MockWith { $null }
        { Set-MOAzureDevOpsModusRepoPermission -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName ghost } |
            Should -Throw '*Repository*not found*'
    }

    It 'honours -WhatIf - grants nothing' {
        Set-MOAzureDevOpsModusRepoPermission -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates -WhatIf
        Should -Invoke Invoke-AdoRest -Times 0 -ParameterFilter { $Method -eq 'Post' }
    }
}
