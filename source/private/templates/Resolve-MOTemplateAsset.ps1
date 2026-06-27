function Resolve-MOTemplateAsset
{
    <#
        .SYNOPSIS
            Downloads a template-library release asset to a private staging area, expanding archives, and
            returns the staged content plus its integrity hash.

        .DESCRIPTION
            Shared materialisation seam for Add-MOTemplate and Update-MOTemplate. Three asset shapes:

              single-file (`.yml`/`.md`) - an azd template, a gh workflow, or a markdown template. Downloaded
                                      as-is; the file itself is the integrity unit and the thing to copy.
              composite action (`.zip` with action.yml at root) - a gh composite action DIRECTORY. Expanded
                                      into a staging dir; the inner action.yml is the entry file `uses:`
                                      resolves and the integrity unit (file SHA256, IntegrityMode 'file').
              directory set (`.zip` WITHOUT action.yml) - a generic multi-file directory asset (e.g. an
                                      issue-template set). Expanded; integrity is the canonical TREE HASH of
                                      the expanded directory (IntegrityMode 'tree'), since there's no single
                                      entry file to anchor on.

            Returns a descriptor with StageRoot (caller MUST remove it when done), ContentPath (the file or
            the expanded directory to copy into place), EntryFile / EntryName (the action.yml or the yml, or
            $null for a directory set), Sha256, IntegrityMode ('file'|'tree') and IsArchive. Downloads route
            through Save-GitHubReleaseAsset so tests mock there instead of hitting the network.

            Integrity note: a single-file asset and a single-file composite action anchor on a plain file
            SHA256 (uppercase, from Get-FileHash); a multi-file directory set anchors on the lowercase
            canonical tree hash from Get-MOTreeHash (matching the release checksums.txt). Test-MOTemplate
            branches on IntegrityMode, so callers compare like with like.

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
            if(Test-Path -LiteralPath $entryFile){
                #--- gh composite action: anchor on the action.yml file SHA256 (single-file shape) ---
                $sha = (Get-FileHash -LiteralPath $entryFile -Algorithm SHA256).Hash
                Write-Verbose "Staged composite-action asset '$AssetName' -> $contentPath (action.yml sha256 $sha)"
                return [pscustomobject]@{
                    IsArchive     = $true
                    IntegrityMode = 'file'
                    StageRoot     = $stageRoot
                    ContentPath   = $contentPath  # directory of files to copy into <name>/
                    EntryFile     = $entryFile    # action.yml (the hashed integrity unit)
                    EntryName     = 'action.yml'
                    Sha256        = $sha
                }
            }

            #--- generic directory set (no action.yml): anchor on the canonical tree hash ---
            $tree = Get-MOTreeHash -Path $contentPath
            Write-Verbose "Staged directory-set asset '$AssetName' -> $contentPath (tree hash $tree)"
            return [pscustomobject]@{
                IsArchive     = $true
                IntegrityMode = 'tree'
                StageRoot     = $stageRoot
                ContentPath   = $contentPath      # directory of files to copy into the dest dir
                EntryFile     = $null
                EntryName     = $null
                Sha256        = $tree
            }
        }

        #--- single-file template (.yml / .md) ---
        $filePath = Join-Path $stageRoot $AssetName
        Save-GitHubReleaseAsset -Uri $Uri -Path $filePath @tokenSplat
        $sha = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash
        Write-Verbose "Staged file asset '$AssetName' (sha256 $sha)"

        return [pscustomobject]@{
            IsArchive     = $false
            IntegrityMode = 'file'
            StageRoot     = $stageRoot
            ContentPath   = $filePath             # single file to copy into place
            EntryFile     = $filePath
            EntryName     = $AssetName
            Sha256        = $sha
        }
    }
}
