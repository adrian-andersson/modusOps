BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    # The private seam this function leans on. They must exist in scope so Pester can mock them.
    # Get-AuthHeader is left real (it is pure and never touches the network).
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
    $functionName = 'New-MOAzureDevOpsModusEnvironment'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'New-MOAzureDevOpsModusEnvironment' {
    BeforeAll {
        $cred = [pscredential]::new('pat', (ConvertTo-SecureString 'secret-pat' -AsPlainText -Force))
    }

    BeforeEach {
        # Hard guarantee: no test ever reaches the network.
        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        # Don't actually sleep during the project-creation poll loop.
        Mock Start-Sleep {}

        # Default simulated org: nothing exists yet, so every get-or-create takes the create path.
        Mock Get-AdoResource { $null }

        # Simulated Azure DevOps responses, keyed on the call being made.
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/process/processes' } -MockWith {
            @{ value = @(@{ name = 'Basic'; id = 'process-basic' }) }
        }
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/projects\?' -and $Method -eq 'Post' } -MockWith {
            @{ id = 'operation-1' }
        }
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/operations/' } -MockWith {
            @{ status = 'succeeded' }
        }
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/projects/' } -MockWith {
            @{ id = 'project-1'; name = 'modusOps' }
        }
        # Catch-all for everything else (preflight, repo/feed creates, identity search).
        Mock Invoke-AdoRest { @{ id = 'generic'; value = @() } }
    }

    Context 'when nothing exists yet' {
        It 'creates the project' {
            New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred
            Should -Invoke Invoke-AdoRest -Times 1 -ParameterFilter { $Uri -match '/projects\?' -and $Method -eq 'Post' }
        }

        It 'creates each requested repository' {
            New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -Repository 'repoA', 'repoB'
            Should -Invoke Invoke-AdoRest -Times 2 -ParameterFilter { $Uri -match '/git/repositories\?' -and $Method -eq 'Post' }
        }

        It 'defaults to the operations repo only (templates come from the GitHub library)' {
            New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred
            Should -Invoke Invoke-AdoRest -Times 1 -ParameterFilter { $Uri -match '/git/repositories\?' -and $Method -eq 'Post' }
            Should -Invoke Invoke-AdoRest -Times 1 -ParameterFilter { $Uri -match '/git/repositories\?' -and $Method -eq 'Post' -and ($Body | ConvertTo-Json) -match 'modusOps' }
        }

        It 'creates the feed' {
            New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred
            Should -Invoke Invoke-AdoRest -Times 1 -ParameterFilter { $Uri -match '/packaging/feeds\?' -and $Method -eq 'Post' }
        }

        It 'returns a summary object describing what was scaffolded' {
            $result = New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -ProjectName 'myProj' -FeedName 'myFeed' -Repository 'r1'
            $result.Organization | Should -Be 'contoso'
            $result.Project      | Should -Be 'myProj'
            $result.Feed         | Should -Be 'myFeed'
            $result.Repositories | Should -Be 'r1'
        }
    }

    Context 'idempotency - when everything already exists' {
        BeforeEach { Mock Get-AdoResource { @{ id = 'existing' } } }

        It 'makes no creating (POST) calls' {
            New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred
            Should -Invoke Invoke-AdoRest -Times 0 -ParameterFilter { $Method -eq 'Post' }
        }
    }

    Context 'safety' {
        It 'honours -WhatIf - performs no mutating calls' {
            New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -WhatIf
            Should -Invoke Invoke-AdoRest -Times 0 -ParameterFilter { $Method -in 'Post', 'Patch' }
        }

        It 'runs a preflight authentication check before doing anything' {
            # The preflight is a plain list GET; it relies on Invoke-AdoRest's default -Method, so the
            # method is unbound here and the URI alone identifies the call.
            New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -WhatIf
            Should -Invoke Invoke-AdoRest -Times 1 -ParameterFilter { $Uri -match '/projects\?api-version' }
        }
    }

    Context 'validation' {
        It 'throws when the requested process template does not exist' {
            Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/process/processes' } -MockWith {
                @{ value = @(@{ name = 'Agile'; id = 'process-agile' }) }
            }
            { New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -ProcessName 'Basic' } |
                Should -Throw '*not found*'
        }
    }
}
