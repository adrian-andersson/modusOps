BeforeAll {

    $currentPath = $(Get-Location).path
    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Get-MOProvisionAllowList'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Get-MOProvisionAllowList' {
    It 'returns the known modusOps Azure DevOps provisioning cmdlets' {
        $allow = Get-MOProvisionAllowList
        $allow | Should -Contain 'Add-MOAzureDevOpsModusBuildValidation'
        $allow | Should -Contain 'Set-MOAzureDevOpsModusRepoPermission'
        $allow | Should -Contain 'Add-MOAzureDevOpsModusResourceAuthorization'
    }

    It 'does not include arbitrary commands' {
        Get-MOProvisionAllowList | Should -Not -Contain 'Remove-Item'
    }

    It 'returns an array even with a single-style call' {
        ,(Get-MOProvisionAllowList) | Should -BeOfType ([array])
    }
}
