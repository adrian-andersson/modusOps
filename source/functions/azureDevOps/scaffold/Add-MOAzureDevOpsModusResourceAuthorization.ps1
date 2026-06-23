function Add-MOAzureDevOpsModusResourceAuthorization
{
    <#
        .SYNOPSIS
            Authorizes a pipeline to use another repository as a resource, via the REST Pipeline
            Permissions API - removing the first-run "this pipeline needs permission" prompt.

        .DESCRIPTION
            When a YAML pipeline references another repo (`resources.repositories`), Azure DevOps blocks
            the first run until the cross-repo access is authorized. This grants that authorization for a
            specific pipeline (not all-pipelines - tighter). Idempotent: skips if already authorized.

        .EXAMPLE
            Add-MOAzureDevOpsModusResourceAuthorization -OrganizationUri 'https://dev.azure.com/anderss' -Credential $pat `
                -RepositoryName modusOpsTemplates -PipelineId 73 -Verbose

            #### DESCRIPTION
            Lets pipeline 73 (the modusOps example) check out the modusOpsTemplates repo.

        .NOTES
            Author: Adrian Andersson
            PAT scope: Pipeline Resources (Use and manage).
            Resource id for a repository is '{projectId}.{repositoryId}'.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    PARAM(
        #Organisation URI, e.g. https://dev.azure.com/myorg
        [Parameter(Mandatory)]
        [string]$OrganizationUri,

        #PAT credential - the PAT is the password (username is ignored)
        [Parameter(Mandatory)]
        [pscredential]$Credential,

        #The repository resource being authorized (the one referenced by the pipeline)
        [Parameter(Mandatory)]
        [string]$RepositoryName,

        #The pipeline (build definition) id being granted access
        [Parameter(Mandatory)]
        [int]$PipelineId,

        #Project that owns the repository and pipeline
        [string]$ProjectName = 'modusOps'
    )
    begin{
        #Return the script name when running verbose, makes it tidier
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        Write-Debug "BoundParams: $($MyInvocation.BoundParameters|Out-String)"
        $ErrorActionPreference = 'Stop'
    }
    process{
        $org     = $OrganizationUri.TrimEnd('/')
        $apiVer  = '7.1-preview.1'
        $headers = Get-AuthHeader -Credential $Credential

        #Resolve project + repository ids (resource id = projectId.repoId)
        $project = Get-AdoResource -Uri "$org/_apis/projects/$ProjectName`?api-version=7.1" -Headers $headers
        if(-not $project){ throw "Project '$ProjectName' not found." }
        $repo = Get-AdoResource -Uri "$org/$ProjectName/_apis/git/repositories/$RepositoryName`?api-version=7.1" -Headers $headers
        if(-not $repo){ throw "Repository '$RepositoryName' not found." }

        $resourceId = "$($project.id).$($repo.id)"
        $permUri = "$org/$ProjectName/_apis/pipelines/pipelinePermissions/repository/$resourceId`?api-version=$apiVer"

        #Idempotent: skip if this pipeline is already authorized for the resource
        $current = Invoke-AdoRest -Uri $permUri -Headers $headers
        if($current.pipelines | Where-Object { $_.id -eq $PipelineId -and $_.authorized }){
            Write-Verbose "Pipeline $PipelineId is already authorized for repository '$RepositoryName'"
            return
        }

        $body = @{ pipelines = @(@{ id = $PipelineId; authorized = $true }) }
        if($PSCmdlet.ShouldProcess("$RepositoryName", "Authorize pipeline $PipelineId to use this repo")){
            $null = Invoke-AdoRest -Uri $permUri -Method Patch -Body $body -Headers $headers
            Write-Verbose "Authorized pipeline $PipelineId to use repository '$RepositoryName'"
        }
    }
}
