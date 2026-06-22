function New-MOAzureDevOpsModusPipeline
{
    <#
        .SYNOPSIS
            Creates an Azure DevOps YAML pipeline pointing at a file in a repository, via the REST API.

        .DESCRIPTION
            Idempotent: if a pipeline with the same name already exists it is returned, not recreated.
            The created pipeline adopts whatever `trigger:` the referenced YAML declares.

        .EXAMPLE
            New-MOAzureDevOpsModusPipeline -OrganizationUri 'https://dev.azure.com/anderss' -Credential $pat `
                -RepositoryName modusOpsTemplates -Name 'modusOpsTemplates Tag On Merge' -YamlPath '/ci/tagOnMerge.yml' -Verbose

            #### DESCRIPTION
            Creates (or returns) the tag-on-merge pipeline for the templates repo.

            #### OUTPUT
            The pipeline object (includes `id`, which equals the build-definition id).

        .NOTES
            Author: Adrian Andersson
            PAT scope: Build (Read & execute) / Edit build pipeline.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    PARAM(
        #Organisation URI, e.g. https://dev.azure.com/myorg
        [Parameter(Mandatory)]
        [string]$OrganizationUri,

        #PAT credential — the PAT is the password (username is ignored)
        [Parameter(Mandatory)]
        [pscredential]$Credential,

        #Repository that holds the YAML
        [Parameter(Mandatory)]
        [string]$RepositoryName,

        #Pipeline display name
        [Parameter(Mandatory)]
        [string]$Name,

        #Repo-relative path to the YAML, e.g. /ci/tagOnMerge.yml
        [Parameter(Mandatory)]
        [string]$YamlPath,

        #Project that owns the repository / pipeline
        [string]$ProjectName = 'modusOps',

        #Pipeline folder
        [string]$Folder = '\'
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
        $base    = "$org/$ProjectName/_apis"

        #Idempotent: return an existing pipeline of the same name
        $existing = (Invoke-AdoRest -Uri "$base/pipelines?api-version=$apiVer" -Headers $headers).value | Where-Object { $_.name -eq $Name } | Select-Object -First 1
        if($existing){
            Write-Verbose "Pipeline '$Name' already exists (id $($existing.id))"
            return $existing
        }

        #Resolve the repository id
        $repo = Get-AdoResource -Uri "$org/$ProjectName/_apis/git/repositories/$RepositoryName`?api-version=7.1" -Headers $headers
        if(-not $repo){ throw "Repository '$RepositoryName' not found." }

        $body = @{
            name          = $Name
            folder        = $Folder
            configuration = @{
                type       = 'yaml'
                path       = $YamlPath
                repository = @{
                    id   = $repo.id
                    type = 'azureReposGit'
                }
            }
        }
        if($PSCmdlet.ShouldProcess($Name, "Create YAML pipeline -> $RepositoryName$YamlPath")){
            $pipeline = Invoke-AdoRest -Uri "$base/pipelines?api-version=$apiVer" -Method Post -Body $body -Headers $headers
            Write-Verbose "Created pipeline '$Name' (id $($pipeline.id))"
            return $pipeline
        }
    }
}
