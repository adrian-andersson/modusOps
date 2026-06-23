BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    # Get-AuthHeader is left real (pure); the REST seam is mocked.
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
    $functionName = 'New-MOAzureDevOpsModusPipeline'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'New-MOAzureDevOpsModusPipeline' {
    BeforeAll {
        $cred = [pscredential]::new('pat', (ConvertTo-SecureString 'secret-pat' -AsPlainText -Force))
    }

    BeforeEach {
        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        Mock Get-AdoResource { [pscustomobject]@{ id = 'repo-1' } }

        # Pipeline list (GET) - none of that name exists yet.
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/pipelines\?' -and $Method -ne 'Post' } -MockWith {
            [pscustomobject]@{ value = @() }
        }
        # Pipeline create (POST).
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/pipelines\?' -and $Method -eq 'Post' } -MockWith {
            [pscustomobject]@{ id = 99; name = 'created' }
        }
    }

    It 'creates the pipeline when none of that name exists' {
        New-MOAzureDevOpsModusPipeline -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOpsTemplates -Name 'PR Validation' -YamlPath '/ci/prValidation.yml'
        Should -Invoke Invoke-AdoRest -Times 1 -ParameterFilter { $Uri -match '/pipelines\?' -and $Method -eq 'Post' }
    }

    It 'returns the created pipeline object' {
        (New-MOAzureDevOpsModusPipeline -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName r -Name 'PR Validation' -YamlPath '/x.yml').id | Should -Be 99
    }

    It 'is idempotent - returns the existing pipeline and creates nothing' {
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/pipelines\?' -and $Method -ne 'Post' } -MockWith {
            [pscustomobject]@{ value = @([pscustomobject]@{ id = 7; name = 'PR Validation' }) }
        }
        $existing = New-MOAzureDevOpsModusPipeline -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName r -Name 'PR Validation' -YamlPath '/x.yml'
        $existing.id | Should -Be 7
        Should -Invoke Invoke-AdoRest -Times 0 -ParameterFilter { $Method -eq 'Post' }
    }

    It 'throws when the repository does not exist' {
        Mock Get-AdoResource { $null }
        { New-MOAzureDevOpsModusPipeline -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName ghost -Name 'New One' -YamlPath '/x.yml' } |
            Should -Throw '*not found*'
    }

    It 'honours -WhatIf - creates nothing' {
        New-MOAzureDevOpsModusPipeline -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName r -Name 'New One' -YamlPath '/x.yml' -WhatIf
        Should -Invoke Invoke-AdoRest -Times 0 -ParameterFilter { $Method -eq 'Post' }
    }
}
