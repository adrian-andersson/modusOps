function Get-MOTemplateRelease
{
    <#
        .SYNOPSIS
            Resolves a modusops-templates GitHub release (latest, or a specific tag) from a source URL.

        .DESCRIPTION
            Parses a GitHub repo URL (owner/repo) out of -Source and queries the Releases API via
            Invoke-GitHubRest. With -Version it fetches that tag; without, the latest release. Returns
            the raw release object (its .tag_name and .assets[] drive the template functions). The
            -Source override is the same code path used for an internal mirror/fork.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    PARAM(
        #GitHub repo URL of the template library, e.g. https://github.com/adrian-andersson/modusops-templates
        [string]$Source = 'https://github.com/adrian-andersson/modusops-templates',
        #Release tag to fetch, e.g. v0.1.0. Omit for the latest release.
        [string]$Version,
        #Optional GitHub token
        [securestring]$Token
    )
    begin{
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        Write-Debug "BoundParams: $($MyInvocation.BoundParameters|Out-String)"
        $ErrorActionPreference = 'Stop'
    }
    process{
        if($Source -notmatch 'github\.com[:/]+(?<owner>[^/]+)/(?<repo>[^/]+?)(\.git)?/?$'){
            throw "Source '$Source' is not a recognisable GitHub repository URL (expected .../owner/repo)."
        }
        $owner = $Matches.owner
        $repo  = $Matches.repo
        $apiBase = "https://api.github.com/repos/$owner/$repo/releases"

        $uri = if($Version){ "$apiBase/tags/$Version" } else { "$apiBase/latest" }
        Write-Verbose "Resolving release: $uri"

        $splat = @{ Uri = $uri }
        if($Token){ $splat.Token = $Token }
        $release = Invoke-GitHubRest @splat
        if(-not $release){ throw "No release found for $owner/$repo$(if($Version){" tag $Version"})." }

        Write-Verbose "Resolved release '$($release.tag_name)' with $(@($release.assets).Count) asset(s)"
        return $release
    }
}
