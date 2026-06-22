function Add-MOAzureDevOpsModusBuildValidation
{
    <#
        .SYNOPSIS
            Adds a build-validation branch policy on a repository branch, via the REST Policy API.

        .DESCRIPTION
            Wires a pipeline (build definition) as a PR build-validation policy on a branch — e.g. the
            prValidation pipeline as a required check on `main`. Idempotent: skips if a build policy for
            the same definition already exists on that branch.

        .EXAMPLE
            Add-MOAzureDevOpsModusBuildValidation -OrganizationUri 'https://dev.azure.com/anderss' -Credential $pat `
                -RepositoryName modusOpsTemplates -BuildDefinitionId 42 -DisplayName 'PR Validation' -Verbose

            #### DESCRIPTION
            Makes build definition 42 a required PR check on modusOpsTemplates/main.

        .NOTES
            Author: Adrian Andersson
            PAT scope: Code (Read, write & manage) — policies are a Code-manage operation.
            Build-policy type id is the well-known '0609b952-1397-4640-95ec-e00a01b2c241'.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
        #Organisation URI, e.g. https://dev.azure.com/myorg
        [Parameter(Mandatory)]
        [string]$OrganizationUri,

        #PAT credential — the PAT is the password (username is ignored)
        [Parameter(Mandatory)]
        [pscredential]$Credential,

        #Repository the policy applies to
        [Parameter(Mandatory)]
        [string]$RepositoryName,

        #Build definition / pipeline id to run as the check
        [Parameter(Mandatory)]
        [int]$BuildDefinitionId,

        #Project that owns the repository
        [string]$ProjectName = 'modusOps',

        #Branch ref the policy applies to
        [string]$Branch = 'refs/heads/main',

        #Policy display name
        [string]$DisplayName = 'PR Validation',

        #Block the merge on failure (required vs optional)
        [bool]$Blocking = $true
    )
    begin{
        #Return the script name when running verbose, makes it tidier
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        Write-Debug "BoundParams: $($MyInvocation.BoundParameters|Out-String)"
        $ErrorActionPreference = 'Stop'
        #Well-known policy type id for 'Build'
        $buildPolicyTypeId = '0609b952-1397-4640-95ec-e00a01b2c241'
    }
    process{
        $org     = $OrganizationUri.TrimEnd('/')
        $apiVer  = '7.1'
        $headers = Get-AuthHeader -Credential $Credential

        #Resolve the repository id
        $repo = Get-AdoResource -Uri "$org/$ProjectName/_apis/git/repositories/$RepositoryName`?api-version=$apiVer" -Headers $headers
        if(-not $repo){ throw "Repository '$RepositoryName' not found." }

        #Idempotent: skip if a build policy for this definition already exists on this repo+branch
        $configs = (Invoke-AdoRest -Uri "$org/$ProjectName/_apis/policy/configurations?api-version=$apiVer" -Headers $headers).value
        $match = $configs | Where-Object {
            $_.type.id -eq $buildPolicyTypeId -and
            $_.settings.buildDefinitionId -eq $BuildDefinitionId -and
            ($_.settings.scope | Where-Object { $_.repositoryId -eq $repo.id -and $_.refName -eq $Branch })
        } | Select-Object -First 1
        if($match){
            Write-Verbose "Build validation for definition $BuildDefinitionId already exists on $RepositoryName $Branch"
            return
        }

        $body = @{
            isEnabled  = $true
            isBlocking = $Blocking
            type       = @{ id = $buildPolicyTypeId }
            settings   = @{
                buildDefinitionId       = $BuildDefinitionId
                queueOnSourceUpdateOnly = $true
                manualQueueOnly         = $false
                displayName             = $DisplayName
                validDuration           = 720
                scope                   = @(
                    @{ repositoryId = $repo.id; refName = $Branch; matchKind = 'Exact' }
                )
            }
        }
        if($PSCmdlet.ShouldProcess("$RepositoryName $Branch", "Add build-validation policy (definition $BuildDefinitionId)")){
            $null = Invoke-AdoRest -Uri "$org/$ProjectName/_apis/policy/configurations?api-version=$apiVer" -Method Post -Body $body -Headers $headers
            Write-Verbose "Added build-validation policy '$DisplayName' on $RepositoryName $Branch"
        }
    }
}
