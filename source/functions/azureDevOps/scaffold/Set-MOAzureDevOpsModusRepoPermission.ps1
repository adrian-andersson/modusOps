function Set-MOAzureDevOpsModusRepoPermission
{
    <#
        .SYNOPSIS
            Grants an identity (default: the project Build Service) repository permissions via the
            Security ACL API - so CI pipelines can push tags and post PR comments.

        .DESCRIPTION
            Resolves the project, repository, and identity, then sets an allow ACE on the Git
            Repositories security namespace for token `repoV2/{projectId}/{repoId}`. Uses `merge` so
            existing permissions are preserved; re-running is safe (sets the same allow bits).

            Default allow bits - Contribute (4) + PullRequestContribute (16384) = 16388 - are exactly
            what `tagOnMerge` (push a tag) and `prValidation` (post a PR comment) need.

        .EXAMPLE
            Set-MOAzureDevOpsModusRepoPermission -OrganizationUri 'https://dev.azure.com/anderss' -Credential $pat `
                -RepositoryName modusOpsTemplates -Verbose

            #### DESCRIPTION
            Grants 'modusOps Build Service (anderss)' Contribute + Contribute-to-PRs on the repo.

        .NOTES
            Author: Adrian Andersson
            PAT scope: Code (Read, write & manage) - managing permissions is a Code-manage operation.
            Git Repositories security namespace id: 2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87.
            Git permission bits: Contribute=4, PullRequestContribute=16384 (combined allow = 16388).
    #>

    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
        #Organisation URI, e.g. https://dev.azure.com/myorg
        [Parameter(Mandatory)]
        [string]$OrganizationUri,

        #PAT credential - the PAT is the password (username is ignored)
        [Parameter(Mandatory)]
        [pscredential]$Credential,

        #Repository to set the permission on
        [Parameter(Mandatory)]
        [string]$RepositoryName,

        #Project that owns the repository
        [string]$ProjectName = 'modusOps',

        #Identity to grant. Defaults to the project Build Service.
        [string]$IdentityName,

        #Allow bitmask. Default Contribute(4) + PullRequestContribute(16384) = 16388
        [int]$Allow = 16388
    )
    begin{
        #Return the script name when running verbose, makes it tidier
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        Write-Debug "BoundParams: $($MyInvocation.BoundParameters|Out-String)"
        $ErrorActionPreference = 'Stop'
        #Well-known Git Repositories security namespace id
        $gitNamespace = '2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87'
    }
    process{
        $org      = $OrganizationUri.TrimEnd('/')
        $orgName  = ($org -split '/')[-1]
        $apiVer   = '7.1'
        $headers  = Get-AuthHeader -Credential $Credential
        $graphApi = "https://vssps.dev.azure.com/$orgName/_apis"

        if(-not $IdentityName){ $IdentityName = "$ProjectName Build Service ($orgName)" }

        #Resolve project + repository ids (token = repoV2/{projectId}/{repoId})
        $project = Get-AdoResource -Uri "$org/_apis/projects/$ProjectName`?api-version=$apiVer" -Headers $headers
        if(-not $project){ throw "Project '$ProjectName' not found." }
        $repo = Get-AdoResource -Uri "$org/$ProjectName/_apis/git/repositories/$RepositoryName`?api-version=$apiVer" -Headers $headers
        if(-not $repo){ throw "Repository '$RepositoryName' not found." }

        #Resolve the identity descriptor
        $filter = [uri]::EscapeDataString($IdentityName)
        $identity = (Invoke-AdoRest -Uri "$graphApi/identities?searchFilter=General&filterValue=$filter&api-version=$apiVer" -Headers $headers).value | Select-Object -First 1
        if(-not $identity){ throw "Identity '$IdentityName' not found." }

        $token = "repoV2/$($project.id)/$($repo.id)"
        $body = @{
            token                = $token
            merge                = $true
            accessControlEntries = @(
                @{
                    descriptor = $identity.descriptor
                    allow      = $Allow
                    deny       = 0
                }
            )
        }
        if($PSCmdlet.ShouldProcess($RepositoryName, "Grant '$IdentityName' allow=$Allow")){
            $null = Invoke-AdoRest -Uri "$org/_apis/accesscontrolentries/$gitNamespace`?api-version=$apiVer" -Method Post -Body $body -Headers $headers
            Write-Verbose "Granted '$IdentityName' allow=$Allow on '$RepositoryName'"
        }
    }
}
