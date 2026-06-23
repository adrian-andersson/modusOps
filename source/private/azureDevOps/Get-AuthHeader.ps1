function Get-AuthHeader
{
    <#
        .SYNOPSIS
            Builds an Azure DevOps Basic-auth header from a PAT supplied as a PSCredential.

        .DESCRIPTION
            Azure DevOps PAT auth is HTTP Basic with an empty username and the PAT as the password.
            This returns the `Authorization` header hashtable ready for Invoke-RestMethod.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    PARAM(
        #PAT credential - the PAT is the password (username is ignored)
        [Parameter(Mandatory)]
        [pscredential]$Credential
    )
    process{
        $pat = $Credential.GetNetworkCredential().Password
        $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
        return @{ Authorization = "Basic $b64" }
    }
}
