function Get-MOTemplateManifest
{
    <#
        .SYNOPSIS
            Downloads and parses the manifest.json attached to a modusops-templates release.

        .DESCRIPTION
            The manifest is the authoritative name->asset index (the tooling resolves templates via it,
            not by parsing filenames). Locates the 'manifest.json' asset on the supplied release object,
            downloads it to a temp file via Save-GitHubReleaseAsset, parses it, and returns the object.
            Throws if the release carries no manifest.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    PARAM(
        #A release object as returned by Get-MOTemplateRelease
        [Parameter(Mandatory)]
        [PSCustomObject]$Release,
        #Optional GitHub token
        [securestring]$Token
    )
    begin{
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        $ErrorActionPreference = 'Stop'
    }
    process{
        $asset = @($Release.assets) | Where-Object { $_.name -eq 'manifest.json' } | Select-Object -First 1
        if(-not $asset){ throw "Release '$($Release.tag_name)' has no manifest.json asset." }

        $temp = Join-Path ([System.IO.Path]::GetTempPath()) "modusops-manifest-$([guid]::NewGuid()).json"
        try{
            $splat = @{ Uri = $asset.browser_download_url; Path = $temp }
            if($Token){ $splat.Token = $Token }
            Save-GitHubReleaseAsset @splat

            $manifest = Get-Content -LiteralPath $temp -Raw | ConvertFrom-Json
            Write-Verbose "Manifest '$($manifest.library)' lists $(@($manifest.templates.PSObject.Properties).Count) template(s)"
            return $manifest
        }
        finally{
            if(Test-Path -LiteralPath $temp){ Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
        }
    }
}
