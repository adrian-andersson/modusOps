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
    $functionName = 'Add-MOAzureDevOpsModusBuildValidation'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Add-MOAzureDevOpsModusBuildValidation' {
    BeforeAll {
        $cred = [pscredential]::new('pat', (ConvertTo-SecureString 'secret-pat' -AsPlainText -Force))
        # The well-known 'Build' policy type id the function uses to detect existing policies.
        $buildPolicyTypeId = '0609b952-1397-4640-95ec-e00a01b2c241'
    }

    BeforeEach {
        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        Mock Get-AdoResource { [pscustomobject]@{ id = 'repo-1' } }

        # Existing policy configurations (GET) - none yet.
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/policy/configurations' -and $Method -ne 'Post' } -MockWith {
            [pscustomobject]@{ value = @() }
        }
        # Policy create (POST).
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/policy/configurations' -and $Method -eq 'Post' } -MockWith {
            [pscustomobject]@{ id = 1 }
        }
    }

    It 'adds a build-validation policy when none exists' {
        Add-MOAzureDevOpsModusBuildValidation -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates -BuildDefinitionId 42
        Should -Invoke Invoke-AdoRest -Times 1 -ParameterFilter { $Uri -match '/policy/configurations' -and $Method -eq 'Post' }
    }

    It 'is idempotent - skips when a matching policy already exists' {
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/policy/configurations' -and $Method -ne 'Post' } -MockWith {
            [pscustomobject]@{ value = @(
                    [pscustomobject]@{
                        type     = [pscustomobject]@{ id = $buildPolicyTypeId }
                        settings = [pscustomobject]@{
                            buildDefinitionId = 42
                            scope             = @([pscustomobject]@{ repositoryId = 'repo-1'; refName = 'refs/heads/main' })
                        }
                    }
                ) }
        }
        Add-MOAzureDevOpsModusBuildValidation -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates -BuildDefinitionId 42
        Should -Invoke Invoke-AdoRest -Times 0 -ParameterFilter { $Method -eq 'Post' }
    }

    It 'throws when the repository does not exist' {
        Mock Get-AdoResource { $null }
        { Add-MOAzureDevOpsModusBuildValidation -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName ghost -BuildDefinitionId 42 } |
            Should -Throw '*not found*'
    }

    It 'honours -WhatIf - adds no policy' {
        Add-MOAzureDevOpsModusBuildValidation -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates -BuildDefinitionId 42 -WhatIf
        Should -Invoke Invoke-AdoRest -Times 0 -ParameterFilter { $Method -eq 'Post' }
    }
}
