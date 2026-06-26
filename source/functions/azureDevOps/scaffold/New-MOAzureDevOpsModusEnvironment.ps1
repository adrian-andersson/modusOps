function New-MOAzureDevOpsModusEnvironment
{
    <#
        .SYNOPSIS
            Scaffolds the modusOps control-plane in an Azure DevOps organisation - project, repositories,
            and an Azure Artifacts feed - using only PowerShell and the Azure DevOps REST API.

        .DESCRIPTION
            Idempotent "get-or-create": every resource is checked before it is created, so it can be
            re-run safely. Authenticates with a PAT supplied as a PSCredential (the PAT is the password;
            the username is ignored).

            Creates, in order:
              1. the project (async - the operation is polled to completion)
              2. the requested git repositories
              3. the Azure Artifacts feed
              4. (best-effort) grants the project Build Service 'reader' on the feed

        .EXAMPLE
            $pat = Get-Credential -UserName 'pat' -Message 'Azure DevOps PAT'
            New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat -Verbose

            #### DESCRIPTION
            Creates (or confirms) the project, repositories, and feed.

            #### OUTPUT
            A summary object listing the organisation, project, feed, and repositories.

        .NOTES
            Author: Adrian Andersson
            PAT scopes: Project and Team (Read, write & manage), Code (Read, write & manage),
            Packaging (Read, write & manage), Identity (Read).
            Only the modern 'https://dev.azure.com/{org}' URI form is handled (not legacy *.visualstudio.com).
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    PARAM(
        #Organisation URI, e.g. https://dev.azure.com/myorg
        [Parameter(Mandatory)]
        [string]$OrganizationUri,

        #PAT credential - the PAT is the password (username is ignored)
        [Parameter(Mandatory)]
        [pscredential]$Credential,

        #Project to create / use
        [string]$ProjectName = 'modusOps',

        #Azure Artifacts feed to create / use
        [string]$FeedName = 'modusOps',

        #Repositories to create in the project. Default: the operations repo only - templates are
        #vendored from the GitHub library (Add-MOTemplate), not provisioned as an AZD repo, and the
        #Toolkit/business modules are consumed from the feed.
        [string[]]$Repository = @('modusOps'),

        #Process template for a new project
        [string]$ProcessName = 'Basic'
    )
    begin{
        #Return the script name when running verbose, makes it tidier
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        #Return the sent variables when running debug
        Write-Debug "BoundParams: $($MyInvocation.BoundParameters|Out-String)"
        $ErrorActionPreference = 'Stop'
    }
    process{
        $org      = $OrganizationUri.TrimEnd('/')
        $orgName  = ($org -split '/')[-1]
        $coreApi  = "$org/_apis"
        $feedsApi = "https://feeds.dev.azure.com/$orgName"
        $graphApi = "https://vssps.dev.azure.com/$orgName/_apis"
        $apiVer   = '7.1'
        $feedApi  = '7.1-preview.1'
        $headers  = Get-AuthHeader -Credential $Credential

        Write-Verbose "Organisation: $orgName"
        Write-Verbose 'Preflight: verifying authentication'
        try{
            $null = Invoke-AdoRest -Uri "$coreApi/projects?api-version=$apiVer" -Headers $headers
        }catch{
            throw "Authentication/connectivity check failed against $org. Verify the org URI and PAT scopes. ($_)"
        }

        #--- Project (async - poll the operation) ---
        $projUri = "$coreApi/projects/$ProjectName`?api-version=$apiVer"
        $project = Get-AdoResource -Uri $projUri -Headers $headers
        if($project){
            Write-Verbose "Project '$ProjectName' already exists (id $($project.id))"
        }else{
            Write-Verbose "Resolving process template '$ProcessName'"
            $processes = (Invoke-AdoRest -Uri "$coreApi/process/processes?api-version=$apiVer" -Headers $headers).value
            $process = $processes | Where-Object { $_.name -eq $ProcessName } | Select-Object -First 1
            if(-not $process){ throw "Process template '$ProcessName' not found. Available: $($processes.name -join ', ')" }

            $body = @{
                name         = $ProjectName
                description  = 'modusOps control-plane project'
                capabilities = @{
                    versioncontrol  = @{ sourceControlType = 'Git' }
                    processTemplate = @{ templateTypeId = $process.id }
                }
            }
            if($PSCmdlet.ShouldProcess($ProjectName, 'Create Azure DevOps project')){
                $op = Invoke-AdoRest -Uri "$coreApi/projects?api-version=$apiVer" -Method Post -Body $body -Headers $headers
                Write-Verbose "Project creation queued (operation $($op.id)); polling..."
                do{
                    Start-Sleep -Seconds 3
                    $status = (Invoke-AdoRest -Uri "$coreApi/operations/$($op.id)?api-version=$apiVer" -Headers $headers).status
                    Write-Verbose "  operation status: $status"
                }while($status -in 'notSet', 'queued', 'inProgress')
                if($status -ne 'succeeded'){ throw "Project creation failed (status: $status)" }
                $project = Invoke-AdoRest -Uri $projUri -Headers $headers
                Write-Verbose "Created project '$ProjectName' (id $($project.id))"
            }
        }

        #--- Repositories ---
        foreach($repoName in $Repository){
            $repoUri = "$org/$ProjectName/_apis/git/repositories/$repoName`?api-version=$apiVer"
            if(Get-AdoResource -Uri $repoUri -Headers $headers){
                Write-Verbose "Repository '$repoName' already exists"
            }elseif($PSCmdlet.ShouldProcess($repoName, 'Create git repository')){
                $body = @{ name = $repoName; project = @{ id = $project.id } }
                $null = Invoke-AdoRest -Uri "$org/$ProjectName/_apis/git/repositories?api-version=$apiVer" -Method Post -Body $body -Headers $headers
                Write-Verbose "Created repository '$repoName'"
            }
        }

        #--- Feed ---
        $feedUri = "$feedsApi/$ProjectName/_apis/packaging/feeds/$($FeedName)?api-version=$feedApi"
        $feed = Get-AdoResource -Uri $feedUri -Headers $headers
        if($feed){
            Write-Verbose "Feed '$FeedName' already exists (id $($feed.id))"
        }elseif($PSCmdlet.ShouldProcess($FeedName, 'Create Azure Artifacts feed')){
            $body = @{ name = $FeedName }
            $feed = Invoke-AdoRest -Uri "$feedsApi/$ProjectName/_apis/packaging/feeds?api-version=$feedApi" -Method Post -Body $body -Headers $headers
            Write-Verbose "Created feed '$FeedName' (id $($feed.id))"
        }

        #--- Feed permission (best-effort) ---
        if($feed){
            try{
                $buildSvcName = "$ProjectName Build Service ($orgName)"
                $filter = [uri]::EscapeDataString($buildSvcName)
                $idUri = "$graphApi/identities?searchFilter=General&filterValue=$filter&api-version=$apiVer"
                $identity = (Invoke-AdoRest -Uri $idUri -Headers $headers).value | Select-Object -First 1
                if($identity -and $PSCmdlet.ShouldProcess($buildSvcName, "Grant 'reader' on feed '$FeedName'")){
                    $permBody = @(@{ identityDescriptor = $identity.descriptor; role = 'reader' })
                    $permUri = "$feedsApi/$ProjectName/_apis/packaging/feeds/$($feed.id)/permissions?api-version=$feedApi"
                    $null = Invoke-AdoRest -Uri $permUri -Method Patch -Body $permBody -Headers $headers
                    Write-Verbose "Granted 'reader' to '$buildSvcName'"
                }elseif(-not $identity){
                    Write-Warning "Could not resolve build service identity '$buildSvcName'. Grant feed Reader manually in the feed settings."
                }
            }catch{
                Write-Warning "Feed permission grant failed (best-effort): $_. Grant feed Reader manually in the feed settings."
            }
        }

        Write-Verbose 'modusOps environment scaffold complete'
        [PSCustomObject]@{
            Organization = $orgName
            Project      = $ProjectName
            Feed         = $FeedName
            Repositories = $Repository
        }
    }
}
