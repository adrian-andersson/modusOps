function Invoke-AdoRest
{
    <#
        .SYNOPSIS
            Thin wrapper around Invoke-RestMethod for Azure DevOps JSON calls.

        .DESCRIPTION
            Sends a JSON request to an Azure DevOps REST endpoint. The body, when supplied, is converted
            to JSON (depth 20 to allow for nested push change-sets). Errors are terminating.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    PARAM(
        #Full request URI
        [Parameter(Mandatory)]
        [string]$Uri,
        #HTTP method
        [string]$Method = 'Get',
        #Optional body object (converted to JSON)
        $Body,
        #Auth + accept headers
        [Parameter(Mandatory)]
        [hashtable]$Headers
    )
    process{
        $splat = @{
            Uri         = $Uri
            Method      = $Method
            Headers     = $Headers
            ContentType = 'application/json'
            ErrorAction = 'Stop'
        }
        if($null -ne $Body){ $splat.Body = ($Body | ConvertTo-Json -Depth 20) }
        return Invoke-RestMethod @splat
    }
}
