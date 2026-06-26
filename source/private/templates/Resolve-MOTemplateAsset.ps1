function Resolve-MOTemplateAsset
{
    <#
        .SYNOPSIS
            Downloads a template-library release asset to a private staging area, expanding archives, and
            returns the staged content plus its integrity hash.

        .DESCRIPTION
            Shared materialisation seam for Add-MOTemplate and Update-MOTemplate. Two asset shapes:

              single-file (`.yml`)  - an azd template. Downloaded as-is; the file itself is the integrity
                                      unit and the thing to copy into the consumer repo.
              archive (`.zip`)      - a gh composite action (a DIRECTORY: action.yml [+ optional sidecars]).
                                      Downloaded and Expand-Archive'd into a staging dir; the inner
                                      action.yml is the entry file `uses:` resolves and the integrity unit.

            Returns a descriptor with StageRoot (caller MUST remove it when done), ContentPath (the file or
            the expanded directory to copy into place), EntryFile / EntryName (the action.yml or the yml),
            Sha256 (hash of the entry file) and IsArchive. Downloads route through Save-GitHubReleaseAsset so
            tests mock there instead of hitting the network.

            Integrity note: while a gh template is a single action.yml the anchor is that file's SHA256, so
            Test-MOTemplate stays a plain lock-vs-file check. A future multi-file composite action would need
            a canonical tree hash instead (the release checksums.txt already computes one).

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
            Write-Verbose "Staged archive asset '$AssetName' -> $contentPath (action.yml sha256 $sha)"

            return [pscustomobject]@{
                IsArchive   = $true
                StageRoot   = $stageRoot
                ContentPath = $contentPath    # directory of files to copy into <name>/
                EntryFile   = $entryFile      # action.yml (the hashed integrity unit)
                EntryName   = 'action.yml'
                Sha256      = $sha
            }
        }

        #--- azd single-file template ---
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
