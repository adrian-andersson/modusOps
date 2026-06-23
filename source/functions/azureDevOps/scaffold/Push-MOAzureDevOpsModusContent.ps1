function Push-MOAzureDevOpsModusContent
{
    <#
        .SYNOPSIS
            Pushes a folder of content into an Azure DevOps git repository as an initial commit, via the
            REST Git Pushes API. Defaults to the content bundled in the module's resource folder.

        .DESCRIPTION
            For an EMPTY repository, creates refs/heads/main with one commit containing every file under
            -SourcePath (recursive, relative paths preserved), then sets main as the default branch.

            Idempotent / safe: if the repo already has commits it is skipped, never clobbered.

            Text files only (rawtext content); binary files would need base64 handling - not implemented.

            When -SourcePath is omitted it resolves to the module's bundled content for the repo:
            `<moduleRoot>/resource/repoContent/<RepositoryName>`.

        .EXAMPLE
            Push-MOAzureDevOpsModusContent -OrganizationUri 'https://dev.azure.com/anderss' -Credential $pat -RepositoryName modusOpsTemplates -Verbose

            #### DESCRIPTION
            Pushes the bundled content for 'modusOpsTemplates' into the (empty) repo.

            #### OUTPUT
            A summary object with the repository, file count, and branch.

        .NOTES
            Author: Adrian Andersson
            PAT scope: Code (Read, write, & manage).
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

        #Repository to push into
        [Parameter(Mandatory)]
        [string]$RepositoryName,

        #Folder to push. Defaults to the module's bundled resource for this repo
        [string]$SourcePath,

        #Project that owns the repository
        [string]$ProjectName = 'modusOps',

        #Wildcard patterns matched against full file paths to skip
        [string[]]$Exclude,

        #Commit message
        [string]$Comment = 'Bootstrap modusOps content'
    )
    begin{
        #Return the script name when running verbose, makes it tidier
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        #Return the sent variables when running debug
        Write-Debug "BoundParams: $($MyInvocation.BoundParameters|Out-String)"
        $ErrorActionPreference = 'Stop'

        if(-not $SourcePath){
            #Resolve bundled resource. $PSScriptRoot is the module root in a built module.
            if($mockPsScriptRoot){
                write-warning 'Assuming PSScriptRoot from $mockPsScriptRoot. This should only be done for testing'
                $resourceFolder = Join-Path $mockPsScriptRoot 'resource'
            }else{
                $resourceFolder = Join-Path $PSScriptRoot 'resource'
            }
            $SourcePath = Join-Path $resourceFolder (Join-Path 'repoContent' $RepositoryName)
        }
        Write-Verbose "SourcePath: $SourcePath"
    }
    process{
        $org      = $OrganizationUri.TrimEnd('/')
        $apiVer   = '7.1'
        $headers  = Get-AuthHeader -Credential $Credential
        $repoBase = "$org/$ProjectName/_apis/git/repositories/$RepositoryName"

        #Confirm the repo exists, and that it is empty (don't clobber existing content)
        $repo = Invoke-AdoRest -Uri "$repoBase`?api-version=$apiVer" -Headers $headers
        $refs = Invoke-AdoRest -Uri "$repoBase/refs?api-version=$apiVer" -Headers $headers
        if($refs.count -gt 0){
            Write-Warning "Repository '$RepositoryName' already has content ($($refs.count) ref(s)); skipping to avoid clobbering."
            return
        }

        if(!(Test-Path -LiteralPath $SourcePath)){ throw "Source path not found: $SourcePath" }
        $source = (Resolve-Path -LiteralPath $SourcePath).Path
        $files = Get-ChildItem -LiteralPath $source -Recurse -File
        if($Exclude){
            $files = $files | Where-Object { $full = $_.FullName; -not ($Exclude | Where-Object { $full -like $_ }) }
        }
        if(-not $files){ throw "No files found under '$source' (after excludes)." }

        #Build the change set - rawtext content, repo-relative forward-slash paths
        $changes = @(foreach($f in $files){
            $rel = ($f.FullName.Substring($source.Length).TrimStart('\', '/')) -replace '\\', '/'
            $content = (Get-Content -LiteralPath $f.FullName -Raw) ?? ''
            Write-Verbose "  + /$rel"
            @{
                changeType = 'add'
                item       = @{ path = "/$rel" }
                newContent = @{ content = $content; contentType = 'rawtext' }
            }
        })

        #Initial commit into the empty repo (oldObjectId of all-zeros = create the ref)
        $body = @{
            refUpdates = @(@{ name = 'refs/heads/main'; oldObjectId = '0000000000000000000000000000000000000000' })
            commits    = @(@{ comment = $Comment; changes = $changes })
        }

        if($PSCmdlet.ShouldProcess($RepositoryName, "Push $($changes.Count) file(s) as initial commit on main")){
            $null = Invoke-AdoRest -Uri "$repoBase/pushes?api-version=$apiVer" -Method Post -Body $body -Headers $headers
            Write-Verbose "Pushed $($changes.Count) file(s) to '$RepositoryName'."

            #Pushing the first branch to an empty repo already makes it the default - this is belt-and-braces.
            #Best-effort: never let setting the default branch abort a successful content push.
            $repoId = $repo.id
            try{
                $null = Invoke-AdoRest -Uri "$org/$ProjectName/_apis/git/repositories/$repoId`?api-version=$apiVer" -Method Patch -Body @{ defaultBranch = 'refs/heads/main' } -Headers $headers
                Write-Verbose 'Default branch set to main.'
            }catch{
                Write-Warning "Content pushed, but setting default branch failed (best-effort): $_. Set the default branch to main in repo settings if needed."
            }
        }


        [PSCustomObject]@{
            Repository = $RepositoryName
            Files      = $changes.Count
            Branch     = 'main'
        }
    }
}
