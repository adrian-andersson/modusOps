function Find-MOTemplate
{
    <#
        .SYNOPSIS
            Discovers templates available in the modusOps template library (npm-search style).

        .DESCRIPTION
            Resolves a release of the template library (latest, or -Version) and reads its manifest.json,
            emitting one object per template (name, description, platforms, version, asset). Optionally
            filter by -Name (wildcards) and/or -Platform. Read-only discovery — nothing is written
            locally; use Add-MOTemplate to vendor one.

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
        #Filter to templates that ship the given platform asset
        [ValidateSet('azd','gh')]
        [string]$Platform,
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

        $releaseSplat = @{ Source = $Source } + $tokenSplat
        if($Version){ $releaseSplat.Version = $Version }
        $release = Get-MOTemplateRelease @releaseSplat
        $manifest = Get-MOTemplateManifest -Release $release @tokenSplat

        foreach($prop in ($manifest.templates.PSObject.Properties | Sort-Object Name)){
            if($prop.Name -notlike $Name){ continue }
            $platforms = @($prop.Value.platforms)
            if($Platform -and $platforms -notcontains $Platform){ continue }

            [pscustomobject]@{
                Name        = $prop.Name
                Description = $prop.Value.description
                Platforms   = $platforms
                Version     = $release.tag_name
                Asset       = if($Platform){ $prop.Value.assets.$Platform } else { $prop.Value.assets.$($platforms[0]) }
            }
        }
    }
}
