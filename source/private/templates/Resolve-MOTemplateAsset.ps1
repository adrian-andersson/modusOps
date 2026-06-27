function Resolve-MOTemplateAsset
{
    <#
        .SYNOPSIS
            Downloads a template-library release asset to a private staging area, expanding archives, and
            returns the staged content plus its integrity hash.

        .DESCRIPTION
            Shared materialisation seam for Add-MOTemplate and Update-MOTemplate. Two asset shapes, both
            anchored on a single file SHA256:

              single-file (`.yml`/`.md`) - an azd template, a gh workflow, or a markdown template. Downloaded
                                      as-is; the file itself is the integrity unit and the thing to copy.
              composite action (`.zip` with action.yml at root) - a gh composite action DIRECTORY. Expanded
                                      into a staging dir; the inner action.yml is the entry file `uses:`
                                      resolves and the hashed integrity unit.

            Returns a descriptor with StageRoot (caller MUST remove it when done), ContentPath (the file or
            the expanded directory to copy into place), EntryFile / EntryName (the action.yml or the yml),
            Sha256 and IsArchive. Downloads route through Save-GitHubReleaseAsset so tests mock there instead
            of hitting the network.

            Integrity is always a plain file SHA256 (the single file, or the inner action.yml), so
            Test-MOTemplate stays a simple lock-vs-file check. (A multi-file directory asset would need a
            canonical tree hash; that path was retired - issue templates ship as individual single-file
            assets instead - and can return if a multi-file atomic asset ever appears.)

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    PARAM(
        #Asset download URL (the release asset's browser_download_url)
        [Parameter(Mandatory)]
        [string]$Uri,

        #Asset file name as published on the release, e.g. azd.foo.yml or gh.foo.zip. The extension drives
        #the vendored shape (.zip => composite-action directory).
        [Parameter(Mandatory)]
        [string]$AssetName,

        #Optional GitHub token (private mirrors / rate limit)
        [securestring]$Token
    )
    begin{
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        $ErrorActionPreference = 'Stop'
    }
    process{
        $tokenSplat = @{}
        if($Token){ $tokenSplat.Token = $Token }

        $stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) "modusops-asset-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

        if($AssetName -like '*.zip'){
            #--- gh composite action: download the archive and expand it ---
            $zipPath = Join-Path $stageRoot $AssetName
            Save-GitHubReleaseAsset -Uri $Uri -Path $zipPath @tokenSplat

            $contentPath = Join-Path $stageRoot 'content'
            New-Item -ItemType Directory -Path $contentPath -Force | Out-Null
            Expand-Archive -LiteralPath $zipPath -DestinationPath $contentPath -Force
            Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue

            $entryFile = Join-Path $contentPath 'action.yml'
            if(-not (Test-Path -LiteralPath $entryFile)){
                throw "Asset '$AssetName' did not contain an action.yml at its root (a gh composite action requires one)."
            }
            $sha = (Get-FileHash -LiteralPath $entryFile -Algorithm SHA256).Hash
            Write-Verbose "Staged composite-action asset '$AssetName' -> $contentPath (action.yml sha256 $sha)"

            return [pscustomobject]@{
                IsArchive   = $true
                StageRoot   = $stageRoot
                ContentPath = $contentPath    # directory of files to copy into <name>/
                EntryFile   = $entryFile      # action.yml (the hashed integrity unit)
                EntryName   = 'action.yml'
                Sha256      = $sha
            }
        }

        #--- single-file template (.yml / .md) ---
        $filePath = Join-Path $stageRoot $AssetName
        Save-GitHubReleaseAsset -Uri $Uri -Path $filePath @tokenSplat
        $sha = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash
        Write-Verbose "Staged file asset '$AssetName' (sha256 $sha)"

        return [pscustomobject]@{
            IsArchive   = $false
            StageRoot   = $stageRoot
            ContentPath = $filePath           # single file to copy into place
            EntryFile   = $filePath
            EntryName   = $AssetName
            Sha256      = $sha
        }
    }
}
