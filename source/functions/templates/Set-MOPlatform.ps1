function Set-MOPlatform
{
    <#
        .SYNOPSIS
            Sets the default Platform Type (azd|gh) for the repo so commands stop re-taking -Platform.

        .DESCRIPTION
            Writes defaults.platform into the consumer's .modusops.lock (creating the lock if absent). Once
            set, Find/Add/Update/Get-MOTemplate and the scaffold cmdlets resolve the platform from here via
            Resolve-MOPlatform, so you only pass -Platform to override. The first Add-MOTemplate also seeds
            this automatically from what it resolved - Set-MOPlatform is for setting or changing it explicitly.

        .EXAMPLE
            Set-MOPlatform gh

            #### DESCRIPTION
            Records gh as the repo default in ./.modusops.lock.

            #### OUTPUT
            { Platform = gh; Source = lockfile }

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    PARAM(
        #The default platform to record
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('azd','gh')]
        [string]$Platform,
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

        if(-not $PSCmdlet.ShouldProcess($lockPath, "Set default platform to '$Platform'")){ return }

        $lock = Read-MOTemplateLock -Path $lockPath
        if(-not $lock.defaults){ $lock.defaults = @{} }
        $lock.defaults.platform = $Platform
        Write-MOTemplateLock -Lock $lock -Path $lockPath
        Write-Verbose "Default platform set to '$Platform' in $lockPath"

        [pscustomobject]@{ Platform = $Platform; Source = 'lockfile' }
    }
}
