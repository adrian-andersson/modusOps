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
            pipeline compile- or run-time. Always pin a version in practice - omitting -Version takes the
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

        #Target platform asset to vendor. Omit to resolve it (lockfile default, else repo-shape detection).
        [ValidateSet('azd','gh')]
        [string]$Platform,

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

        $projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
        $lockPath    = Join-Path $projectRoot $LockFile

        #Resolve the platform once (explicit -Platform > lockfile default > repo-shape auto-detect).
        #Splat -Platform only when supplied, so an unbound value isn't rejected by the resolver's ValidateSet.
        $platformSplat = @{}
        if($Platform){ $platformSplat.Platform = $Platform }
        $resolvedPlatform = Resolve-MOPlatform @platformSplat -ProjectPath $projectRoot -LockFile $LockFile

        #Resolve release + manifest, then map name -> platform asset
        $releaseSplat = @{ Source = $Source } + $tokenSplat
        if($Version){ $releaseSplat.Version = $Version }
        $release = Get-MOTemplateRelease @releaseSplat
        $manifest = Get-MOTemplateManifest -Release $release @tokenSplat

        $entry = $manifest.templates.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
        if(-not $entry){ throw "Template '$Name' is not in the manifest for release '$($release.tag_name)'." }
        $mEntry = $entry.Value

        $assetName = $mEntry.assets.$resolvedPlatform
        if(-not $assetName){ throw "Template '$Name' has no '$resolvedPlatform' asset (platforms: $($mEntry.platforms -join ', '))." }

        $asset = @($release.assets) | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
        if(-not $asset){ throw "Release '$($release.tag_name)' is missing asset '$assetName'." }

        #Category drives WHERE it lands. 'repoScaffold' = a fixed in-repo dest declared by the manifest
        #(repo furniture); anything else - pipeline, or an older manifest with no category - vendors into
        #the consumer-chosen templates dir, as before.
        $category  = if($mEntry.category){ [string]$mEntry.category } else { 'pipeline' }
        $kind      = if($mEntry.kind -and $mEntry.kind.$resolvedPlatform){ [string]$mEntry.kind.$resolvedPlatform } else { $null }
        $repoType  = if($mEntry.repoType){ [string]$mEntry.repoType } else { $null }
        $isArchive = $assetName -like '*.zip'

        if($category -eq 'repoScaffold'){
            $destRel = $mEntry.dest.$resolvedPlatform
            if(-not $destRel){ throw "repoScaffold template '$Name' has no 'dest' for platform '$resolvedPlatform' in the manifest." }
            $relativePath = ([string]$destRel) -replace '\\','/'
            $localPath    = Join-Path $projectRoot $relativePath   # a single file at its fixed dest
        }else{
            #Pipeline: asset extension drives layout - .zip (composite action) -> <name>/action.yml; else <name>.yml.
            $templatesDir = Join-Path $projectRoot $Path
            if($isArchive){
                $localPath    = Join-Path (Join-Path $templatesDir $Name) 'action.yml'
                $relativePath = (Join-Path (Join-Path $Path $Name) 'action.yml') -replace '\\','/'
            }else{
                $localName    = "$Name.yml"                 # drop the platform prefix once vendored
                $localPath    = Join-Path $templatesDir $localName
                $relativePath = (Join-Path $Path $localName) -replace '\\','/'
            }
        }

        if(-not $PSCmdlet.ShouldProcess($localPath, "Vendor template '$Name' ($resolvedPlatform) from $($release.tag_name)")){
            return
        }

        #Download (and expand, for archives) into a staging area, then lay the files down.
        $staged = Resolve-MOTemplateAsset -Uri $asset.browser_download_url -AssetName $assetName @tokenSplat
        try{
            if($staged.IsArchive){
                #A composite action copies the expanded dir (action.yml + any sidecars) into <name>/.
                $destDir = Split-Path -Parent $localPath
                if(-not (Test-Path -LiteralPath $destDir)){ New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                Copy-Item -Path (Join-Path $staged.ContentPath '*') -Destination $destDir -Recurse -Force
            }else{
                $destDir = Split-Path -Parent $localPath
                if(-not (Test-Path -LiteralPath $destDir)){ New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                Copy-Item -LiteralPath $staged.ContentPath -Destination $localPath -Force
            }
            $sha = $staged.Sha256
        }
        finally{
            if(Test-Path -LiteralPath $staged.StageRoot){ Remove-Item -LiteralPath $staged.StageRoot -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Write-Verbose "Vendored '$Name' -> $relativePath (sha256 $sha)"

        #Record in the lockfile. Seed defaults.platform on first use so later commands inherit it.
        $lock = Read-MOTemplateLock -Path $lockPath
        $lock.source = $Source
        if(-not $lock.defaults){ $lock.defaults = @{} }
        if(-not $lock.defaults.platform){ $lock.defaults.platform = $resolvedPlatform }
        $lock.templates[$Name] = @{
            version   = $release.tag_name
            platform  = $resolvedPlatform
            category  = $category
            kind      = $kind
            repoType  = $repoType
            asset     = $assetName
            path      = $relativePath
            sha256    = $sha
            url       = $asset.browser_download_url
        }
        Write-MOTemplateLock -Lock $lock -Path $lockPath

        return [pscustomobject]($lock.templates[$Name] + @{ name = $Name })
    }
}
