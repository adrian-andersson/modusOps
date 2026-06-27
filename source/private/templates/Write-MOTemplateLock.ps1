function Write-MOTemplateLock
{
    <#
        .SYNOPSIS
            Writes a lock structure back to a .modusops.lock file as stable, sorted JSON.

        .DESCRIPTION
            Serialises the hashtable structure produced by Read-MOTemplateLock. Template entries are
            emitted in sorted name order so the lockfile produces minimal, review-friendly diffs. The
            `defaults` block (e.g. defaults.platform) is emitted only when non-empty, so locks that never
            set a default stay byte-identical to before. Written UTF8 without a trailing newline drift.
            Pairs with Read-MOTemplateLock.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    PARAM(
        #The lock structure: @{ lockfileVersion; source; templates = @{ name = @{...} } }
        [Parameter(Mandatory)]
        [hashtable]$Lock,
        #Full path to the .modusops.lock file
        [Parameter(Mandatory)]
        [string]$Path
    )
    process{
        $orderedTemplates = [ordered]@{}
        foreach($name in ($Lock.templates.Keys | Sort-Object)){
            $orderedTemplates[$name] = $Lock.templates[$name]
        }

        $out = [ordered]@{
            lockfileVersion = if($Lock.lockfileVersion){ $Lock.lockfileVersion } else { 1 }
            source          = $Lock.source
        }
        #Only emit defaults when something is set, so existing lockfiles don't gain an empty block.
        if($Lock.defaults -and $Lock.defaults.Keys.Count -gt 0){
            $orderedDefaults = [ordered]@{}
            foreach($k in ($Lock.defaults.Keys | Sort-Object)){ $orderedDefaults[$k] = $Lock.defaults[$k] }
            $out.defaults = $orderedDefaults
        }
        $out.templates = $orderedTemplates

        $json = $out | ConvertTo-Json -Depth 10
        Set-Content -LiteralPath $Path -Value $json -Encoding utf8
    }
}
