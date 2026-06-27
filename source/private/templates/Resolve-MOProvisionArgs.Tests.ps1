BeforeAll {

    $currentPath = $(Get-Location).path
    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Resolve-MOProvisionArgs'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Resolve-MOProvisionArgs' {
    It 'binds a whole-value placeholder preserving type (int stays int)' {
        $splat = Resolve-MOProvisionArgs -With @{ BuildDefinitionId = '{buildId}' } -Values @{ buildId = 42 }
        $splat.BuildDefinitionId | Should -Be 42
        $splat.BuildDefinitionId | Should -BeOfType ([int])
    }

    It 'interpolates an embedded placeholder into a string' {
        $splat = Resolve-MOProvisionArgs -With @{ IdentityName = '{repo} Build Service' } -Values @{ repo = 'modusOps' }
        $splat.IdentityName | Should -Be 'modusOps Build Service'
    }

    It 'threads context params the cmdlet accepts, and drops those it does not' {
        $splat = Resolve-MOProvisionArgs -With @{ RepositoryName = '{repo}' } -Values @{ repo = 'r' } `
            -Context @{ OrganizationUri = 'https://x'; ProjectName = 'p' } `
            -AcceptedParameters @('OrganizationUri','RepositoryName')
        $splat.OrganizationUri | Should -Be 'https://x'
        $splat.RepositoryName  | Should -Be 'r'
        $splat.ContainsKey('ProjectName') | Should -BeFalse   # not accepted by this cmdlet
    }

    It 'does not let context override a value the step already set' {
        $splat = Resolve-MOProvisionArgs -With @{ ProjectName = 'fromStep' } -Values @{} `
            -Context @{ ProjectName = 'fromContext' } -AcceptedParameters @('ProjectName')
        $splat.ProjectName | Should -Be 'fromStep'
    }

    It 'skips null context values' {
        $splat = Resolve-MOProvisionArgs -With @{} -Values @{} -Context @{ ProjectName = $null } -AcceptedParameters @('ProjectName')
        $splat.ContainsKey('ProjectName') | Should -BeFalse
    }

    It 'throws on an unknown placeholder' {
        { Resolve-MOProvisionArgs -With @{ RepositoryName = '{missing}' } -Values @{} } | Should -Throw '*missing*'
    }
}
