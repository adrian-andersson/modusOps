function Read-MOTemplateLock
{
    <#
        .SYNOPSIS
            Reads a .modusops.lock file into a mutable hashtable structure.

        .DESCRIPTION
            Returns the lockfile as @{ lockfileVersion; source; defaults = @{...}; templates = @{ name = @{...} } }.
            The templates and defaults members are hashtables (not PSCustomObjects) so callers can add/replace
            entries directly. `defaults` carries repo-level settings - notably `defaults.platform`, the default
            Platform Type resolved by Resolve-MOPlatform so commands don't re-take -Platform. When the lockfile
            does not exist, an empty default structure is returned so callers never special-case "first install".
            Pairs with Write-MOTemplateLock.

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
            return @{ lockfileVersion = 1; source = $null; defaults = @{}; templates = @{} }
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
        $defaults = @{}
        if($raw.defaults){
            foreach($field in $raw.defaults.PSObject.Properties){ $defaults[$field.Name] = $field.Value }
        }
        return @{
            lockfileVersion = if($raw.lockfileVersion){ $raw.lockfileVersion } else { 1 }
            source          = $raw.source
            defaults        = $defaults
            templates       = $templates
        }
    }
}
