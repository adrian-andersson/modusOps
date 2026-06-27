function Find-MOArchetype
{
    <#
        .SYNOPSIS
            Discovers the repo-scaffold sets (archetypes) available in the template library.

        .DESCRIPTION
            Resolves a library release, reads its manifest.json, and emits one object per set (name, type,
            platforms, member count, description). A set is a named bundle you apply in one call with
            Add-MORepoScaffold. Member count is resolved against the effective platform (so a 'selector' set
            reports how many templates currently match); with -Platform omitted it defaults to the repo's
            resolved platform, so the catalog shows only relevant sets (pass -AllPlatforms to override).

        .EXAMPLE
            Find-MOArchetype

            #### DESCRIPTION
            Lists every set in the latest library release for the repo's platform.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    PARAM(
        #Filter to set names (supports wildcards)
        [string]$Name = '*',
        #Release tag to inspect, e.g. v1. Omit for the latest release.
        [string]$Version,
        #Filter to sets that support the given platform. Omit to default to the repo's platform.
        [ValidateSet('azd','gh')]
        [string]$Platform,
        #Show sets for every platform instead of the repo's resolved platform
        [switch]$AllPlatforms,
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
        $ErrorActionPreference = 'Stop'
    }
    process{
        $tokenSplat = @{}
        if($Token){ $tokenSplat.Token = $Token }

        $effPlatform = if($Platform){
            $Platform
        }elseif($AllPlatforms){
            $null
        }else{
            try{ Resolve-MOPlatform -ProjectPath $ProjectPath -LockFile $LockFile }catch{ $null }
        }

        $releaseSplat = @{ Source = $Source } + $tokenSplat
        if($Version){ $releaseSplat.Version = $Version }
        $release = Get-MOTemplateRelease @releaseSplat
        $manifest = Get-MOTemplateManifest -Release $release @tokenSplat
        if(-not $manifest.sets){ return }

        foreach($prop in ($manifest.sets.PSObject.Properties | Sort-Object Name)){
            if($prop.Name -notlike $Name){ continue }
            $set = $prop.Value
            $platforms = @($set.platforms)
            if($effPlatform -and $platforms -and ($platforms -notcontains $effPlatform)){ continue }
            $type = if($set.type){ [string]$set.type } else { 'archetype' }

            #Resolve a concrete member count when we know the platform; otherwise show the declared step count.
            $members = $null
            if($effPlatform){
                try{ $members = @(Resolve-MOArchetype -Manifest $manifest -Archetype $prop.Name -Platform $effPlatform -WarningAction SilentlyContinue).Count }catch{ $members = $null }
            }elseif($type -ne 'selector'){
                $members = @($set.steps).Count
            }

            [pscustomobject]@{
                Name        = $prop.Name
                Type        = $type
                Platforms   = $platforms
                Members     = $members
                Description = $set.description
                Version     = $release.tag_name
            }
        }
    }
}
