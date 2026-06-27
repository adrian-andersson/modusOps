function Get-MOTemplate
{
    <#
        .SYNOPSIS
            Lists the modusOps templates vendored into the consumer repo (reads .modusops.lock).

        .DESCRIPTION
            Offline. Reads the lockfile and emits one object per installed template (name, version,
            platform, path, sha256, source). Optionally filter by -Name. No network access.

        .EXAMPLE
            Get-MOTemplate

            #### DESCRIPTION
            Lists everything pinned in ./.modusops.lock.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    PARAM(
        #Filter to a single template name (supports wildcards)
        [string]$Name = '*',
        #Consumer repo root holding the lockfile
        [string]$ProjectPath = '.',
        #Lockfile name (relative to ProjectPath)
        [string]$LockFile = '.modusops.lock'
    )
    begin{
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        $ErrorActionPreference = 'Stop'
    }
    process{
        $projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
        $lockPath = Join-Path $projectRoot $LockFile
        $lock = Read-MOTemplateLock -Path $lockPath

        foreach($key in ($lock.templates.Keys | Sort-Object)){
            if($key -notlike $Name){ continue }
            $entry = $lock.templates[$key]
            [pscustomobject]@{
                Name     = $key
                Version  = $entry.version
                Platform = $entry.platform
                Category = if($entry.category){ $entry.category } else { 'pipeline' }
                Kind     = $entry.kind
                Path     = $entry.path
                Sha256   = $entry.sha256
                Source   = $lock.source
            }
        }
    }
}
