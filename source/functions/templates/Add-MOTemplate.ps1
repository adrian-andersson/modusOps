function Add-MOTemplate
{
    <#
        .SYNOPSIS
            Vendors one or more modusOps pipeline templates from the library into the local repo and pins them.

        .DESCRIPTION
            The authoring-time "install" verb (npm-install for templates). Resolves the named template(s)
            in a GitHub release of the template library, downloads each asset, writes it locally under
            -Path (vendor-at-fetch), records source URL + version + asset + SHA256 in the consumer's
            .modusops.lock, and returns the lock entry per template.

            -Name accepts an array, so several templates can be vendored together at the same version in
            one call (e.g. -Name registerModusOpsFeeds,installModusOpsModules). Every requested name is
            resolved against the manifest first - a typo or missing asset throws before anything is
            downloaded or written, so a batch can't leave the repo half-applied. The lockfile is written
            once for the whole batch.

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

        .EXAMPLE
            Add-MOTemplate -Name registerModusOpsFeeds,installModusOpsModules,sendDiscordChannelMessage -Version v1

            #### DESCRIPTION
            Vendors all three templates from release v1 in one call, pinning each in .modusops.lock.

            #### OUTPUT
            One lockfile entry per template.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([psobject[]])]
    PARAM(
        #Template name(s) as listed in the library manifest - one or more, vendored together at the same version.
        [Parameter(Mandatory)]
        [string[]]$Name,

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

        #Resolve release + manifest once for the whole batch, then map each name -> platform asset + dest.
        $releaseSplat = @{ Source = $Source } + $tokenSplat
        if($Version){ $releaseSplat.Version = $Version }
        $release = Get-MOTemplateRelease @releaseSplat
        $manifest = Get-MOTemplateManifest -Release $release @tokenSplat

        #Phase 1 - resolve every requested name to a concrete vendor plan. Any miss (unknown name, no
        #platform asset, asset absent from the release) throws here, before a single byte is downloaded or
        #written, so a typo in a batch can't leave the repo half-applied.
        $plans = [System.Collections.Generic.List[object]]::new()
        foreach($n in $Name){
            $entry = $manifest.templates.PSObject.Properties | Where-Object { $_.Name -eq $n } | Select-Object -First 1
            if(-not $entry){ throw "Template '$n' is not in the manifest for release '$($release.tag_name)'." }
            $mEntry = $entry.Value

            $assetName = $mEntry.assets.$resolvedPlatform
            if(-not $assetName){ throw "Template '$n' has no '$resolvedPlatform' asset (platforms: $($mEntry.platforms -join ', '))." }

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
                if(-not $destRel){ throw "repoScaffold template '$n' has no 'dest' for platform '$resolvedPlatform' in the manifest." }
                $relativePath = ([string]$destRel) -replace '\\','/'
                $localPath    = Join-Path $projectRoot $relativePath   # a single file at its fixed dest
            }else{
                #Pipeline: asset extension drives layout - .zip (composite action) -> <name>/action.yml; else <name>.yml.
                $templatesDir = Join-Path $projectRoot $Path
                if($isArchive){
                    $localPath    = Join-Path (Join-Path $templatesDir $n) 'action.yml'
                    $relativePath = (Join-Path (Join-Path $Path $n) 'action.yml') -replace '\\','/'
                }else{
                    $localName    = "$n.yml"                 # drop the platform prefix once vendored
                    $localPath    = Join-Path $templatesDir $localName
                    $relativePath = (Join-Path $Path $localName) -replace '\\','/'
                }
            }

            $plans.Add([pscustomobject]@{
                Name = $n; AssetName = $assetName; Url = $asset.browser_download_url
                Category = $category; Kind = $kind; RepoType = $repoType
                LocalPath = $localPath; RelativePath = $relativePath
            })
        }

        #Phase 2 - apply each plan; mutate the lock in memory, write it once at the end.
        #Seed defaults.platform on first use so later commands inherit it.
        $lock = Read-MOTemplateLock -Path $lockPath
        $lock.source = $Source
        if(-not $lock.defaults){ $lock.defaults = @{} }
        if(-not $lock.defaults.platform){ $lock.defaults.platform = $resolvedPlatform }

        $results = [System.Collections.Generic.List[object]]::new()
        $applied = $false
        foreach($p in $plans){
            if(-not $PSCmdlet.ShouldProcess($p.LocalPath, "Vendor template '$($p.Name)' ($resolvedPlatform) from $($release.tag_name)")){
                continue
            }

            #Download (and expand, for archives) into a staging area, then lay the files down.
            $staged = Resolve-MOTemplateAsset -Uri $p.Url -AssetName $p.AssetName @tokenSplat
            try{
                $destDir = Split-Path -Parent $p.LocalPath
                if(-not (Test-Path -LiteralPath $destDir)){ New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                if($staged.IsArchive){
                    #A composite action copies the expanded dir (action.yml + any sidecars) into <name>/.
                    Copy-Item -Path (Join-Path $staged.ContentPath '*') -Destination $destDir -Recurse -Force
                }else{
                    Copy-Item -LiteralPath $staged.ContentPath -Destination $p.LocalPath -Force
                }
                $sha = $staged.Sha256
            }
            finally{
                if(Test-Path -LiteralPath $staged.StageRoot){ Remove-Item -LiteralPath $staged.StageRoot -Recurse -Force -ErrorAction SilentlyContinue }
            }
            Write-Verbose "Vendored '$($p.Name)' -> $($p.RelativePath) (sha256 $sha)"

            $lock.templates[$p.Name] = @{
                version   = $release.tag_name
                platform  = $resolvedPlatform
                category  = $p.Category
                kind      = $p.Kind
                repoType  = $p.RepoType
                asset     = $p.AssetName
                path      = $p.RelativePath
                sha256    = $sha
                url       = $p.Url
            }
            $applied = $true
            $results.Add([pscustomobject]($lock.templates[$p.Name] + @{ name = $p.Name }))
        }

        if($applied){ Write-MOTemplateLock -Lock $lock -Path $lockPath }

        #Cast so the element type matches the declared OutputType; PowerShell unrolls a single-item
        #array back to a scalar, so existing single-name callers see no behavioural change.
        return [pscustomobject[]]$results
    }
}
