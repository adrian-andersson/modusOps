function Test-MOTemplate
{
    <#
        .SYNOPSIS
            Offline integrity check of vendored templates against the lockfile (npm-ci style).

        .DESCRIPTION
            For each template in .modusops.lock, recomputes the local file's SHA256 and compares it to the
            pinned hash. Reports one object per template (Name, Status, Version, Path, Expected, Actual) with
            a Status of:
              OK       - file present and hash matches the lockfile
              Drifted  - file present but hash differs (locally edited; vendored files are managed)
              Missing  - lockfile entry has no corresponding local file
            Provision markers (archetype REST actions) are skipped - there is no file to hash. No network
            access by default, so it is a cheap CI gate.

            -CheckUpdate additionally queries the library once for the latest release and annotates each row
            with Latest + UpdateAvailable (this is the only path that touches the network).

        .EXAMPLE
            Test-MOTemplate

            #### DESCRIPTION
            Verifies every vendored template under ./ against ./.modusops.lock (offline).

        .EXAMPLE
            Test-MOTemplate -CheckUpdate

            #### DESCRIPTION
            As above, plus a Latest / UpdateAvailable column showing whether a newer library version exists.

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
        [string]$LockFile = '.modusops.lock',
        #Also query the library for the latest version (online) and add Latest + UpdateAvailable columns
        [switch]$CheckUpdate,
        #Template library URL for -CheckUpdate (defaults to the lockfile's recorded source)
        [string]$Source,
        #Optional GitHub token for -CheckUpdate
        [securestring]$Token
    )
    begin{
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        $ErrorActionPreference = 'Stop'
    }
    process{
        $projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
        $lockPath = Join-Path $projectRoot $LockFile
        $lock = Read-MOTemplateLock -Path $lockPath

        #Resolve the latest library version once (only when asked - this is the sole network call).
        $latestTag = $null
        if($CheckUpdate){
            $effSource = if($Source){ $Source } elseif($lock.source){ $lock.source } else { 'https://github.com/adrian-andersson/modusops-templates' }
            $relSplat = @{ Source = $effSource }
            if($Token){ $relSplat.Token = $Token }
            $latestTag = (Get-MOTemplateRelease @relSplat).tag_name
            Write-Verbose "Latest library release: $latestTag"
        }

        foreach($key in ($lock.templates.Keys | Sort-Object)){
            if($key -notlike $Name){ continue }
            $entry = $lock.templates[$key]
            #Provision markers are REST actions, not vendored files - there's nothing on disk to hash, so skip.
            if($entry.kind -eq 'provision'){ continue }
            $localPath = Join-Path $projectRoot $entry.path

            if(-not (Test-Path -LiteralPath $localPath)){
                $status = 'Missing'
                $actual = $null
            }else{
                $actual = (Get-FileHash -LiteralPath $localPath -Algorithm SHA256).Hash
                $status = if($actual -eq $entry.sha256){ 'OK' } else { 'Drifted' }
            }
            if($status -ne 'OK'){ Write-Warning "Template '$key' integrity: $status ($($entry.path))" }

            $row = [ordered]@{
                Name     = $key
                Status   = $status
                Version  = $entry.version
                Path     = $entry.path
                Expected = $entry.sha256
                Actual   = $actual
            }
            if($CheckUpdate){
                #Rolling-integer compare; fall back to "differs => behind" for non-vN tags.
                $behind = $false
                if($latestTag -and $entry.version -and ($entry.version -ne $latestTag)){
                    $pinN = if("$($entry.version)" -match '^v(\d+)$'){ [int]$Matches[1] } else { $null }
                    $latN = if("$latestTag" -match '^v(\d+)$'){ [int]$Matches[1] } else { $null }
                    $behind = if($null -ne $pinN -and $null -ne $latN){ $latN -gt $pinN } else { $true }
                }
                $row.Latest          = $latestTag
                $row.UpdateAvailable = $behind
            }
            [pscustomobject]$row
        }
    }
}
