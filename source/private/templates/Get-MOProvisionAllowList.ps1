function Get-MOProvisionAllowList
{
    <#
        .SYNOPSIS
            Returns the allow-list of cmdlets an archetype 'provision' step may invoke.

        .DESCRIPTION
            A manifest is a privileged input vendored from the library, so a 'provision' step must NOT be able
            to name an arbitrary command - that would be a manifest-driven code-execution vector. Add-MORepoScaffold
            validates every provision step's cmdlet against this fixed list before binding args or invoking it;
            anything not listed is rejected. The list is deliberately limited to modusOps' own Azure DevOps
            provisioning cmdlets (the REST-plane scaffold seam).

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    PARAM()
    process{
        ,@(
            'Add-MOAzureDevOpsModusBuildValidation'
            'Add-MOAzureDevOpsModusResourceAuthorization'
            'Set-MOAzureDevOpsModusRepoPermission'
        )
    }
}
