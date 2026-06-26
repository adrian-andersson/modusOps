function Test-MOTemplate
{
    <#
        .SYNOPSIS
            Offline integrity check of vendored templates against the lockfile (npm-ci style).

        .DESCRIPTION
            For each template in .modusops.lock, recomputes the local file's SHA256 and compares it to
            the pinned hash. Reports one object per template with a Status of:
              OK       - file present and hash matches the lockfile
              Drifted  - file present but hash differs (locally edited; vendored dirs are managed)
              Missing  - lockfile entry has no corresponding local file
            No network access. CI-able as an opt-in gate: -PassThru emits the rows; a non-zero count of
            non-OK rows is the signal to fail a pipeline.

        .EXAMPLE
            Test-MOTemplate

            #### DESCRIPTION
            Verifies every vendored template under ./ against ./.modusops.lock.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    PARAM(
        #Filter to a single template name (supports wildcards)
        [string]$Name = '*',
        #Consumer repo root holding the lockfile and templates
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
            $localPath = Join-Path $projectRoot $entry.path

            if(-not (Test-Path -LiteralPath $localPath)){
                $status = 'Missing'
                $actual = $null
            }else{
                $actual = (Get-FileHash -LiteralPath $localPath -Algorithm SHA256).Hash
                $status = if($actual -eq $entry.sha256){ 'OK' } else { 'Drifted' }
            }
            if($status -ne 'OK'){ Write-Warning "Template '$key' integrity: $status ($($entry.path))" }

            [pscustomobject]@{
                Name     = $key
                Status   = $status
                Path     = $entry.path
                Expected = $entry.sha256
                Actual   = $actual
            }
        }
    }
}
