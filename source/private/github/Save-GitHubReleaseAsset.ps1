function Save-GitHubReleaseAsset
{
    <#
        .SYNOPSIS
            Downloads a single GitHub release asset verbatim to a local path.

        .DESCRIPTION
            The download seam for the template-library functions. Writes the asset bytes exactly as
            served (vendor-at-fetch) so the local file's SHA256 matches the published asset - the value
            pinned in .modusops.lock. Kept as its own private function so tests mock here instead of
            hitting the network; a mock typically drops known content at -Path under a Pester TestDrive.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    PARAM(
        #Asset download URL (the release asset's browser_download_url)
        [Parameter(Mandatory)]
        [string]$Uri,
        #Destination file path (parent directory must exist)
        [Parameter(Mandatory)]
        [string]$Path,
        #Optional GitHub token (private mirrors / rate limit). The token is the password.
        [securestring]$Token
    )
    process{
        $headers = @{ 'Accept' = 'application/octet-stream' }
        if($Token){
            $plain = [System.Net.NetworkCredential]::new('', $Token).Password
            $headers['Authorization'] = "Bearer $plain"
        }
        Invoke-WebRequest -Uri $Uri -Headers $headers -OutFile $Path -ErrorAction Stop
    }
}
