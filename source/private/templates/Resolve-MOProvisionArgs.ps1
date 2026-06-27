function Resolve-MOProvisionArgs
{
    <#
        .SYNOPSIS
            Builds the parameter splat for an archetype 'provision' step from its with-map, the caller's
            placeholder values, and the shared scaffold context.

        .DESCRIPTION
            Pure binding seam for Add-MORepoScaffold (no cmdlet is invoked here). Three inputs combine into one
            splat:

              -With     the step's declared args (param -> value), values may contain {placeholders}
              -Values   the caller's -With hashtable, supplying placeholder values
              -Context  shared scaffold context (e.g. OrganizationUri / ProjectName / Token)

            Placeholder rules: a value that is exactly "{key}" is replaced by the RAW value from -Values (so an
            int stays an int, e.g. BuildDefinitionId); a value that merely contains "{key}" is string-interpolated.
            A referenced key missing from -Values throws. Context entries are added only when the target cmdlet
            actually declares that parameter (-AcceptedParameters) and the step didn't already set it, so context
            threads through without forcing every cmdlet to accept every shared param.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    PARAM(
        #The step's declared args (param name -> value, values may contain {placeholders})
        [Parameter(Mandatory)]
        [hashtable]$With,
        #Placeholder values supplied by the caller (-With on Add-MORepoScaffold)
        [hashtable]$Values = @{},
        #Shared scaffold context to thread through where accepted (OrganizationUri / ProjectName / Token / ...)
        [hashtable]$Context = @{},
        #Parameter names the target cmdlet accepts (context is filtered to these)
        [string[]]$AcceptedParameters = @()
    )
    process{
        # Local placeholder resolver: whole-value "{key}" preserves type; embedded "{key}" interpolates.
        $expand = {
            param($value)
            if($value -isnot [string]){ return $value }
            $whole = [regex]::Match($value, '^\{(\w+)\}$')
            if($whole.Success){
                $k = $whole.Groups[1].Value
                if(-not $Values.ContainsKey($k)){ throw "Provision step references unknown placeholder '{$k}'." }
                return $Values[$k]
            }
            return [regex]::Replace($value, '\{(\w+)\}', {
                param($m)
                $k = $m.Groups[1].Value
                if(-not $Values.ContainsKey($k)){ throw "Provision step references unknown placeholder '{$k}'." }
                [string]$Values[$k]
            })
        }

        $splat = @{}
        foreach($key in $With.Keys){
            $splat[$key] = & $expand $With[$key]
        }
        foreach($key in $Context.Keys){
            if($null -eq $Context[$key]){ continue }
            if($AcceptedParameters -and ($AcceptedParameters -notcontains $key)){ continue }
            if(-not $splat.ContainsKey($key)){ $splat[$key] = $Context[$key] }
        }
        return $splat
    }
}
