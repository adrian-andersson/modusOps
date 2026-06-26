function Invoke-GitHubRest
{
    <#
        .SYNOPSIS
            Thin wrapper around Invoke-RestMethod for GitHub REST API JSON calls.

        .DESCRIPTION
            Sends a JSON request to a GitHub REST endpoint (api.github.com). Sets the GitHub API
            version + Accept headers, and a Bearer token when one is supplied. The body, when present,
            is converted to JSON. Errors are terminating. This is the single HTTP seam for the
            template-library (GitHub Releases) functions - the counterpart to Invoke-AdoRest on the
            Azure DevOps side - so tests mock here, never the network.

        .NOTES
            Author: Adrian Andersson
            Unauthenticated Releases calls are rate-limited to 60/hr/IP; pass -Token in CI.
    #>
    [CmdletBinding()]
    PARAM(
        #Full request URI, e.g. https://api.github.com/repos/owner/repo/releases/latest
        [Parameter(Mandatory)]
        [string]$Uri,
        #HTTP method
        [string]$Method = 'Get',
        #Optional body object (converted to JSON)
        $Body,
        #Optional GitHub token (raises the rate limit / reaches private mirrors). The token is the password.
        [securestring]$Token
    )
    process{
        $headers = @{
            'Accept'               = 'application/vnd.github+json'
            'X-GitHub-Api-Version' = '2022-11-28'
        }
        if($Token){
            $plain = [System.Net.NetworkCredential]::new('', $Token).Password
            $headers['Authorization'] = "Bearer $plain"
        }

        $splat = @{
            Uri         = $Uri
            Method      = $Method
            Headers     = $headers
            ErrorAction = 'Stop'
        }
        if($null -ne $Body){
            $splat.Body        = ($Body | ConvertTo-Json -Depth 20)
            $splat.ContentType = 'application/json'
        }
        return Invoke-RestMethod @splat
    }
}
