function Get-AdoResource
{
    <#
        .SYNOPSIS
            GETs an Azure DevOps resource, returning $null on 404.

        .DESCRIPTION
            Used for get-or-create checks: returns the resource if it exists, or $null when the endpoint
            responds 404. Any other error is re-thrown.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    PARAM(
        #Full request URI
        [Parameter(Mandatory)]
        [string]$Uri,
        #Auth + accept headers
        [Parameter(Mandatory)]
        [hashtable]$Headers
    )
    process{
        try{
            return Invoke-AdoRest -Uri $Uri -Headers $Headers -Method Get
        }catch{
            if($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound){ return $null }
            throw
        }
    }
}
