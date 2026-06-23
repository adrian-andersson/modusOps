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
    $functionName = 'Add-MOAzureDevOpsModusResourceAuthorization'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Add-MOAzureDevOpsModusResourceAuthorization' {
    BeforeAll {
        $cred = [pscredential]::new('pat', (ConvertTo-SecureString 'secret-pat' -AsPlainText -Force))
    }

    BeforeEach {
        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        # Both the project and the repository resolve to an id.
        Mock Get-AdoResource { [pscustomobject]@{ id = 'guid-1' } }

        # Current permissions (GET) - pipeline not yet authorized.
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match 'pipelinePermissions' -and $Method -ne 'Patch' } -MockWith {
            [pscustomobject]@{ pipelines = @() }
        }
        # Authorize (PATCH).
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match 'pipelinePermissions' -and $Method -eq 'Patch' } -MockWith {
            [pscustomobject]@{ pipelines = @([pscustomobject]@{ id = 73; authorized = $true }) }
        }
    }

    It 'authorizes the pipeline when not already authorized' {
        Add-MOAzureDevOpsModusResourceAuthorization -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates -PipelineId 73
        Should -Invoke Invoke-AdoRest -Times 1 -ParameterFilter { $Uri -match 'pipelinePermissions' -and $Method -eq 'Patch' }
    }

    It 'is idempotent - skips when the pipeline is already authorized' {
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match 'pipelinePermissions' -and $Method -ne 'Patch' } -MockWith {
            [pscustomobject]@{ pipelines = @([pscustomobject]@{ id = 73; authorized = $true }) }
        }
        Add-MOAzureDevOpsModusResourceAuthorization -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates -PipelineId 73
        Should -Invoke Invoke-AdoRest -Times 0 -ParameterFilter { $Method -eq 'Patch' }
    }

    It 'throws when the project does not exist' {
        Mock Get-AdoResource -ParameterFilter { $Uri -match '/projects/' } -MockWith { $null }
        { Add-MOAzureDevOpsModusResourceAuthorization -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates -PipelineId 73 } |
            Should -Throw '*Project*not found*'
    }

    It 'throws when the repository does not exist' {
        Mock Get-AdoResource -ParameterFilter { $Uri -match '/git/repositories/' } -MockWith { $null }
        { Add-MOAzureDevOpsModusResourceAuthorization -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName ghost -PipelineId 73 } |
            Should -Throw '*Repository*not found*'
    }

    It 'honours -WhatIf - authorizes nothing' {
        Add-MOAzureDevOpsModusResourceAuthorization -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates -PipelineId 73 -WhatIf
        Should -Invoke Invoke-AdoRest -Times 0 -ParameterFilter { $Method -eq 'Patch' }
    }
}
