function Resolve-MOPlatform
{
    <#
        .SYNOPSIS
            Resolves the effective target platform (azd|gh) so public cmdlets don't have to re-take -Platform.

        .DESCRIPTION
            The single seam every template/scaffold cmdlet routes through to decide which platform it is
            operating on. Precedence (highest first):

              1. an explicit -Platform argument          (one-off override; always wins)
              2. the lockfile default (defaults.platform) (the "set once" answer - Set-MOPlatform writes it)
              3. auto-detect from repo shape              (.github/ => gh ; azure-pipelines.yml => azd)
              4. ambiguous / none                          -> throw a directive error (CI stays non-interactive)

            Throwing rather than prompting keeps it safe in pipelines. Get-MOPlatform wraps this for a
            non-throwing report; Add-MOTemplate seeds defaults.platform from the resolved value on first use.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([string])]
    PARAM(
        #Explicit platform override. When supplied it wins outright.
        [ValidateSet('azd','gh')]
        [string]$Platform,
        #Consumer repo root (used for the lockfile default and repo-shape detection)
        [string]$ProjectPath = '.',
        #Lockfile name (relative to ProjectPath)
        [string]$LockFile = '.modusops.lock'
    )
    process{
        # 1. Explicit argument wins.
        if($Platform){
            Write-Verbose "Platform from explicit -Platform: $Platform"
            return $Platform
        }

        $projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path

        # 2. Lockfile default (set once via Set-MOPlatform / seeded by the first Add).
        $lock = Read-MOTemplateLock -Path (Join-Path $projectRoot $LockFile)
        if($lock.defaults -and $lock.defaults.platform){
            $fromLock = [string]$lock.defaults.platform
            Write-Verbose "Platform from lockfile default: $fromLock"
            return $fromLock
        }

        # 3. Auto-detect from repo shape.
        $hasGh  = Test-Path -LiteralPath (Join-Path $projectRoot '.github')
        $hasAzd = Test-Path -LiteralPath (Join-Path $projectRoot 'azure-pipelines.yml')
        if($hasGh -and -not $hasAzd){ Write-Verbose 'Platform auto-detected: gh (.github present)'; return 'gh' }
        if($hasAzd -and -not $hasGh){ Write-Verbose 'Platform auto-detected: azd (azure-pipelines.yml present)'; return 'azd' }

        # 4. Can't tell - make the caller decide.
        throw "Cannot determine the target platform (azd|gh) for '$projectRoot'. Set it once with 'Set-MOPlatform <platform>', or pass -Platform."
    }
}
