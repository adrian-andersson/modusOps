function Update-MOTemplate
{
    <#
        .SYNOPSIS
            Re-pulls vendored templates at a newer library version, overwriting only what changed.

        .DESCRIPTION
            The npm-update verb. For each installed template (all, or -Name), resolves the target release
            (latest, or -Version), downloads the asset, and compares its SHA256 to the lockfile pin:
              - hash changed  -> overwrites the local file and updates the lockfile (Status 'Changed')
              - hash unchanged -> leaves the file untouched, only re-pins the version (Status 'Unchanged')
            So the version coordinate always advances but the working-tree diff shows only real changes.
            Vendored files are a managed directory (node_modules model) — local edits are not preserved.

        .EXAMPLE
            Update-MOTemplate -Version v0.2.0

            #### DESCRIPTION
            Re-pins every installed template to v0.2.0, rewriting only those whose bytes changed.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    PARAM(
        #Template name to update (supports wildcards). Omit to update every installed template.
        [string]$Name = '*',
        #Target release tag, e.g. v0.2.0. Omit for the latest release.
        [string]$Version,
        #Consumer repo root holding the templates dir and lockfile
        [string]$ProjectPath = '.',
        #Lockfile name (relative to ProjectPath)
        [string]$LockFile = '.modusops.lock',
        #Template library GitHub repo URL. Defaults to the source recorded in the lockfile.
        [string]$Source,
        #Optional GitHub token
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
        $lockPath = Join-Path $projectRoot $LockFile
        $lock = Read-MOTemplateLock -Path $lockPath

        $targets = @($lock.templates.Keys | Where-Object { $_ -like $Name } | Sort-Object)
        if($targets.Count -eq 0){ throw "No installed template matches '$Name' in $LockFile. Use Add-MOTemplate to install." }

        $effectiveSource = if($Source){ $Source } elseif($lock.source){ $lock.source } else { 'https://github.com/adrian-andersson/modusops-templates' }

        #Resolve the target release + manifest once for the whole batch
        $releaseSplat = @{ Source = $effectiveSource } + $tokenSplat
        if($Version){ $releaseSplat.Version = $Version }
        $release = Get-MOTemplateRelease @releaseSplat
        $manifest = Get-MOTemplateManifest -Release $release @tokenSplat

        foreach($key in $targets){
            $entry = $lock.templates[$key]
            $platform = $entry.platform

            $mEntry = $manifest.templates.PSObject.Properties | Where-Object { $_.Name -eq $key } | Select-Object -First 1
            if(-not $mEntry){ Write-Warning "Template '$key' is not in release '$($release.tag_name)'; skipping."; continue }
            $assetName = $mEntry.Value.assets.$platform
            $asset = @($release.assets) | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
            if(-not $asset){ Write-Warning "Release '$($release.tag_name)' is missing asset '$assetName' for '$key'; skipping."; continue }

            $localPath = Join-Path $projectRoot $entry.path

            if(-not $PSCmdlet.ShouldProcess($localPath, "Update template '$key' to $($release.tag_name)")){
                continue
            }

            #Download (and expand, for gh archives) into a staging area and compare before overwriting
            $staged = Resolve-MOTemplateAsset -Uri $asset.browser_download_url -AssetName $assetName @tokenSplat
            try{
                $newSha = $staged.Sha256

                if($newSha -eq $entry.sha256){
                    $status = 'Unchanged'
                }else{
                    $dir = Split-Path -Parent $localPath
                    if(-not (Test-Path -LiteralPath $dir)){ New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                    if($staged.IsArchive){
                        Copy-Item -Path (Join-Path $staged.ContentPath '*') -Destination $dir -Recurse -Force
                    }else{
                        Copy-Item -LiteralPath $staged.ContentPath -Destination $localPath -Force
                    }
                    $status = 'Changed'
                }
            }
            finally{
                if(Test-Path -LiteralPath $staged.StageRoot){ Remove-Item -LiteralPath $staged.StageRoot -Recurse -Force -ErrorAction SilentlyContinue }
            }

            $fromVersion = $entry.version
            #Re-pin version + (when changed) sha/url
            $entry.version = $release.tag_name
            $entry.asset   = $assetName
            $entry.url     = $asset.browser_download_url
            if($status -eq 'Changed'){ $entry.sha256 = $newSha }
            $lock.templates[$key] = $entry

            [pscustomobject]@{
                Name    = $key
                Status  = $status
                From    = $fromVersion
                To      = $release.tag_name
            }
        }

        if($Source){ $lock.source = $Source }
        Write-MOTemplateLock -Lock $lock -Path $lockPath
    }
}
