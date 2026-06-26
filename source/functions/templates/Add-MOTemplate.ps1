function Add-MOTemplate
{
    <#
        .SYNOPSIS
            Vendors a modusOps pipeline template from the library into the local repo and pins it.

        .DESCRIPTION
            The authoring-time "install" verb (npm-install for templates). Resolves the named template
            in a GitHub release of the template library, downloads its asset, writes it locally under
            -Path (vendor-at-fetch), records source URL + version + asset + SHA256 in the consumer's
            .modusops.lock, and returns the lock entry.

            Vendored shape follows the asset shape:
              azd (.yml asset)  -> a single file  templates/<name>.yml
              gh  (.zip asset)  -> a composite-action directory  templates/<name>/action.yml (the zip is
                                   expanded; the inner action.yml is the file `uses:` resolves and the hash
                                   pinned in the lockfile).

            The vendored file is committed and reviewed in the consumer's own PR; nothing is fetched at
            pipeline compile- or run-time. Always pin a version in practice — omitting -Version takes the
            latest release, which is recorded explicitly in the lockfile (never a blind "latest").

        .EXAMPLE
            Add-MOTemplate -Name registerModusOpsFeeds -Version v0.1.0

            #### DESCRIPTION
            Vendors templates/registerModusOpsFeeds.yml from release v0.1.0 and records it in .modusops.lock.

            #### OUTPUT
            The lockfile entry (version, platform, asset, path, sha256, url).

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    PARAM(
        #Template name as listed in the library manifest, e.g. registerModusOpsFeeds
        [Parameter(Mandatory)]
        [string]$Name,

        #Release tag to pull, e.g. v0.1.0. Omit for the latest release (recorded explicitly).
        [string]$Version,

        #Target platform asset to vendor
        [ValidateSet('azd','gh')]
        [string]$Platform = 'azd',

        #Consumer repo root holding the templates dir and lockfile
        [string]$ProjectPath = '.',

        #Templates directory (relative to ProjectPath) to write the vendored file into
        [string]$Path = 'templates',

        #Lockfile name (relative to ProjectPath)
        [string]$LockFile = '.modusops.lock',

        #Template library GitHub repo URL (override for an internal mirror/fork)
        [string]$Source = 'https://github.com/adrian-andersson/modusops-templates',

        #Optional GitHub token (raises rate limit / reaches private mirrors)
        [securestring]$Token
    )
    begin{
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        Write-Debug "BoundParams: $($MyInvocation.BoundParameters|Out-String)"
        $ErrorActionPreference = 'Stop'
    }
    process{
        $tokenSplat = @{}
        if($Token){ $tokenSplat.Token = $Token }

        #Resolve release + manifest, then map name -> platform asset
        $releaseSplat = @{ Source = $Source } + $tokenSplat
        if($Version){ $releaseSplat.Version = $Version }
        $release = Get-MOTemplateRelease @releaseSplat
        $manifest = Get-MOTemplateManifest -Release $release @tokenSplat

        $entry = $manifest.templates.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
        if(-not $entry){ throw "Template '$Name' is not in the manifest for release '$($release.tag_name)'." }

        $assetName = $entry.Value.assets.$Platform
        if(-not $assetName){ throw "Template '$Name' has no '$Platform' asset (platforms: $($entry.Value.platforms -join ', '))." }

        $asset = @($release.assets) | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
        if(-not $asset){ throw "Release '$($release.tag_name)' is missing asset '$assetName'." }

        #Resolve local paths. Asset extension drives the vendored layout: .zip (gh composite action) lands
        #in a directory <name>/action.yml; everything else is a single file <name>.yml.
        $projectRoot  = (Resolve-Path -LiteralPath $ProjectPath).Path
        $templatesDir = Join-Path $projectRoot $Path
        $isArchive    = $assetName -like '*.zip'
        if($isArchive){
            $localPath    = Join-Path (Join-Path $templatesDir $Name) 'action.yml'
            $relativePath = (Join-Path (Join-Path $Path $Name) 'action.yml') -replace '\\','/'
        }else{
            $localName    = "$Name.yml"                 # drop the platform prefix once vendored
            $localPath    = Join-Path $templatesDir $localName
            $relativePath = (Join-Path $Path $localName) -replace '\\','/'
        }
        $lockPath     = Join-Path $projectRoot $LockFile

        if(-not $PSCmdlet.ShouldProcess($localPath, "Vendor template '$Name' from $($release.tag_name)")){
            return
        }

        $destDir = Split-Path -Parent $localPath
        if(-not (Test-Path -LiteralPath $destDir)){
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        #Download (and expand, for archives) into a staging area, then lay the files down.
        $staged = Resolve-MOTemplateAsset -Uri $asset.browser_download_url -AssetName $assetName @tokenSplat
        try{
            if($staged.IsArchive){
                #Copy the whole expanded action dir (action.yml + any sidecars) into <name>/.
                Copy-Item -Path (Join-Path $staged.ContentPath '*') -Destination $destDir -Recurse -Force
            }else{
                Copy-Item -LiteralPath $staged.ContentPath -Destination $localPath -Force
            }
            $sha = $staged.Sha256
        }
        finally{
            if(Test-Path -LiteralPath $staged.StageRoot){ Remove-Item -LiteralPath $staged.StageRoot -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Write-Verbose "Vendored '$Name' -> $relativePath (sha256 $sha)"

        #Record in the lockfile
        $lock = Read-MOTemplateLock -Path $lockPath
        $lock.source = $Source
        $lock.templates[$Name] = @{
            version  = $release.tag_name
            platform = $Platform
            asset    = $assetName
            path     = $relativePath
            sha256   = $sha
            url      = $asset.browser_download_url
        }
        Write-MOTemplateLock -Lock $lock -Path $lockPath

        return [pscustomobject]($lock.templates[$Name] + @{ name = $Name })
    }
}
