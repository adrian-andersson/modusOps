function Get-MOPlatform
{
    <#
        .SYNOPSIS
            Reports the effective default Platform Type (azd|gh) and where it was resolved from.

        .DESCRIPTION
            Non-throwing companion to Set-MOPlatform. Returns the resolved platform plus its Source rung:
              lockfile  - read from defaults.platform (set via Set-MOPlatform or seeded by the first Add)
              detected  - inferred from repo shape (.github/ => gh ; azure-pipelines.yml => azd)
              unset     - could not be determined (ambiguous or empty repo); Platform is $null
            Unlike Resolve-MOPlatform (the internal seam, which throws when it can't decide) this never
            throws, so it is safe for "what would the tooling use here?" checks.

        .EXAMPLE
            Get-MOPlatform

            #### OUTPUT
            { Platform = gh; Source = lockfile }

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    PARAM(
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
        $lock = Read-MOTemplateLock -Path (Join-Path $projectRoot $LockFile)

        if($lock.defaults -and $lock.defaults.platform){
            return [pscustomobject]@{ Platform = [string]$lock.defaults.platform; Source = 'lockfile' }
        }

        #No recorded default - report what auto-detection would pick, without throwing.
        try{
            $detected = Resolve-MOPlatform -ProjectPath $projectRoot -LockFile $LockFile
            [pscustomobject]@{ Platform = $detected; Source = 'detected' }
        }catch{
            Write-Verbose "Platform unresolved: $($_.Exception.Message)"
            [pscustomobject]@{ Platform = $null; Source = 'unset' }
        }
    }
}
