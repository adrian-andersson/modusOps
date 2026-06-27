function Find-MOTemplate
{
    <#
        .SYNOPSIS
            Discovers templates available in the modusOps template library (npm-search style).

        .DESCRIPTION
            Resolves a release of the template library (latest, or -Version) and reads its manifest.json,
            emitting one object per template (name, description, platforms, version, asset). Optionally
            filter by -Name (wildcards) and/or -Platform. Read-only discovery - nothing is written
            locally; use Add-MOTemplate to vendor one.

            The Asset field reflects the view: with -Platform it is that platform's single asset; without
            it, the full per-platform asset map (so a dual-platform template shows both azd and gh, not
            just the first one).

        .EXAMPLE
            Find-MOTemplate

            #### DESCRIPTION
            Lists every template in the latest library release.

        .EXAMPLE
            Find-MOTemplate -Name 'send*' -Version v0.1.0

            #### DESCRIPTION
            Lists notification templates present in release v0.1.0.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    PARAM(
        #Filter to template names (supports wildcards)
        [string]$Name = '*',
        #Release tag to inspect, e.g. v0.1.0. Omit for the latest release.
        [string]$Version,
        #Filter to templates that ship the given platform asset. Omit to default to the repo's platform
        #(lockfile default / auto-detect) so the catalog shows only what's relevant; pass -AllPlatforms to override.
        [ValidateSet('azd','gh')]
        [string]$Platform,
        #Show every platform's templates instead of defaulting to the repo's resolved platform
        [switch]$AllPlatforms,
        #Filter to a category: pipeline (compose into a pipeline) or repoScaffold (repo furniture)
        [ValidateSet('pipeline','repoScaffold')]
        [string]$Category,
        #Filter to a kind, e.g. workflow / compositeAction / issueTemplate / prTemplate / stepTemplate
        [string]$Kind,
        #Filter to a repo type for repoScaffold assets, e.g. templatesRepo
        [string]$RepoType,
        #Consumer repo root (used to resolve the default platform when -Platform is omitted)
        [string]$ProjectPath = '.',
        #Lockfile name (relative to ProjectPath)
        [string]$LockFile = '.modusops.lock',
        #Template library GitHub repo URL (override for an internal mirror/fork)
        [string]$Source = 'https://github.com/adrian-andersson/modusops-templates',
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

        #Effective platform filter: explicit -Platform wins; -AllPlatforms shows everything; otherwise
        #default to the repo's resolved platform (non-throwing - if it can't be determined, show all).
        $effPlatform = if($Platform){
            $Platform
        }elseif($AllPlatforms){
            $null
        }else{
            try{ Resolve-MOPlatform -ProjectPath $ProjectPath -LockFile $LockFile }catch{ $null }
        }
        if($effPlatform){ Write-Verbose "Filtering catalog to platform '$effPlatform' (pass -AllPlatforms to see every platform)" }

        $releaseSplat = @{ Source = $Source } + $tokenSplat
        if($Version){ $releaseSplat.Version = $Version }
        $release = Get-MOTemplateRelease @releaseSplat
        $manifest = Get-MOTemplateManifest -Release $release @tokenSplat

        foreach($prop in ($manifest.templates.PSObject.Properties | Sort-Object Name)){
            if($prop.Name -notlike $Name){ continue }
            $platforms = @($prop.Value.platforms)
            if($effPlatform -and $platforms -notcontains $effPlatform){ continue }
            $entryCategory = if($prop.Value.category){ [string]$prop.Value.category } else { 'pipeline' }
            if($Category -and $entryCategory -ne $Category){ continue }

            $entryRepoType = if($prop.Value.repoType){ [string]$prop.Value.repoType } else { $null }
            if($RepoType -and $entryRepoType -ne $RepoType){ continue }

            #Kind filter: against the resolved platform's kind when known, else any platform's kind.
            if($Kind){
                $kinds = if($prop.Value.kind){
                    if($effPlatform){ @($prop.Value.kind.$effPlatform) } else { @($prop.Value.kind.PSObject.Properties.Value) }
                } else { @() }
                if($kinds -notcontains $Kind){ continue }
            }

            [pscustomobject]@{
                Name        = $prop.Name
                Category    = $entryCategory
                Kind        = if($effPlatform -and $prop.Value.kind){ $prop.Value.kind.$effPlatform } else { $prop.Value.kind }
                RepoType    = $entryRepoType
                Description = $prop.Value.description
                Platforms   = $platforms
                Version     = $release.tag_name
                Asset       = if($effPlatform){ $prop.Value.assets.$effPlatform } else { $prop.Value.assets }
            }
        }
    }
}
