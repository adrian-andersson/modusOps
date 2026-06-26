function Read-MOTemplateLock
{
    <#
        .SYNOPSIS
            Reads a .modusops.lock file into a mutable hashtable structure.

        .DESCRIPTION
            Returns the lockfile as @{ lockfileVersion; source; templates = @{ name = @{...} } }. The
            templates member is a hashtable (not a PSCustomObject) so callers can add/replace entries
            directly. When the lockfile does not exist, an empty default structure is returned so callers
            never special-case "first install". Pairs with Write-MOTemplateLock.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    PARAM(
        #Full path to the .modusops.lock file
        [Parameter(Mandatory)]
        [string]$Path
    )
    process{
        if(-not (Test-Path -LiteralPath $Path)){
            return @{ lockfileVersion = 1; source = $null; templates = @{} }
        }

        $raw = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $templates = @{}
        if($raw.templates){
            foreach($prop in $raw.templates.PSObject.Properties){
                $entry = @{}
                foreach($field in $prop.Value.PSObject.Properties){ $entry[$field.Name] = $field.Value }
                $templates[$prop.Name] = $entry
            }
        }
        return @{
            lockfileVersion = if($raw.lockfileVersion){ $raw.lockfileVersion } else { 1 }
            source          = $raw.source
            templates       = $templates
        }
    }
}
