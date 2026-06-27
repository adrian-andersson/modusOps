function Add-MORepoScaffold
{
    <#
        .SYNOPSIS
            Stamps a whole set (archetype) of templates into a repo in one call, and pins each member.

        .DESCRIPTION
            The scaffold "one-liner": where Add-MOTemplate vendors a single asset, Add-MORepoScaffold expands a
            named set from the library manifest and vendors every member, pinning each in .modusops.lock tagged
            with the archetype + the version it came from. Members vendor exactly like Add-MOTemplate (repoScaffold
            members land at their fixed dest under .github/; pipeline members in the templates dir), all at one
            pinned library version so the set is internally consistent.

            Set membership is resolved against the chosen release's manifest (curated steps or a derived selector),
            so it is reproducible from (version + set name). Re-running at a newer -Version re-applies the set,
            overwriting changed members (managed-directory / node_modules model) - that is also the update path.

        .EXAMPLE
            Add-MORepoScaffold -Archetype templateLibrary

            #### DESCRIPTION
            Vendors every member of the templateLibrary set at the latest release into the repo and records them
            in .modusops.lock under that archetype.

        .EXAMPLE
            Add-MORepoScaffold -Archetype templateLibrary -Include workflow -WhatIf

            #### DESCRIPTION
            Previews vendoring just the workflow members of the set; downloads and writes nothing.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    PARAM(
        #Set / archetype name (see Find-MOArchetype)
        [Parameter(Mandatory)]
        [string]$Archetype,
        #Release tag to pull, e.g. v1. Omit for the latest release (recorded explicitly).
        [string]$Version,
        #Target platform. Omit to resolve it (lockfile default, else repo-shape detection).
        [ValidateSet('azd','gh')]
        [string]$Platform,
        #Narrow to members of these kind(s), e.g. workflow
        [string[]]$Include,
        #Consumer repo root holding the templates dir and lockfile
        [string]$ProjectPath = '.',
        #Templates directory (relative to ProjectPath) for any pipeline-category members
        [string]$Path = 'templates',
        #Lockfile name (relative to ProjectPath)
        [string]$LockFile = '.modusops.lock',
        #Template library GitHub repo URL (override for an internal mirror/fork)
        [string]$Source = 'https://github.com/adrian-andersson/modusops-templates',
        #Optional GitHub token
        [securestring]$Token
    )
    begin{
        write-verbose "===========Executing $($MyInvocation.InvocationName)==========="
        Write-Debug "BoundParams: $($MyInvocation.BoundParameters|Out-String)"
        $ErrorActionPreference = 'Stop'
    }
    process{
        $tokenSplat = @{}
        if($Token){ $tokenSplat.Token = $Token }

        $projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
        $lockPath    = Join-Path $projectRoot $LockFile

        #Resolve platform once; splat only when explicit so the resolver's ValidateSet isn't fed an empty value.
        $platformSplat = @{}
        if($Platform){ $platformSplat.Platform = $Platform }
        $resolvedPlatform = Resolve-MOPlatform @platformSplat -ProjectPath $projectRoot -LockFile $LockFile

        #Resolve the release + manifest once, then expand the set.
        $releaseSplat = @{ Source = $Source } + $tokenSplat
        if($Version){ $releaseSplat.Version = $Version }
        $release = Get-MOTemplateRelease @releaseSplat
        $manifest = Get-MOTemplateManifest -Release $release @tokenSplat

        $members = @(Resolve-MOArchetype -Manifest $manifest -Archetype $Archetype -Platform $resolvedPlatform -Include $Include)
        if($members.Count -eq 0){ throw "Archetype '$Archetype' expanded to no members for platform '$resolvedPlatform'." }
        Write-Verbose "Archetype '$Archetype' -> $($members.Count) member(s): $(($members.Template) -join ', ')"

        #Vendor each member at the SAME pinned version so the set is consistent. Add-MOTemplate does the
        #per-member work (dest, hashing, lockfile) and inherits -WhatIf. (It re-resolves the release per call -
        #fine for now; a shared pre-resolved seam would remove the extra fetches.)
        $applied = [System.Collections.Generic.List[string]]::new()
        foreach($m in $members){
            $addSplat = @{
                Name        = $m.Template
                Platform    = $resolvedPlatform
                Version     = $release.tag_name
                ProjectPath = $ProjectPath
                Path        = $Path
                LockFile    = $LockFile
                Source      = $Source
            } + $tokenSplat
            $res = Add-MOTemplate @addSplat
            if($res){ $applied.Add($m.Template) }
        }

        #Tag membership in the lockfile (skipped under -WhatIf, where nothing was vendored).
        if($applied.Count -gt 0){
            $lock = Read-MOTemplateLock -Path $lockPath
            foreach($name in $applied){
                if($lock.templates.ContainsKey($name)){
                    $lock.templates[$name].archetype        = $Archetype
                    $lock.templates[$name].archetypeVersion = $release.tag_name
                }
            }
            Write-MOTemplateLock -Lock $lock -Path $lockPath
        }

        foreach($m in $members){
            [pscustomobject]@{
                Archetype = $Archetype
                Name      = $m.Template
                Kind      = $m.Kind
                Platform  = $resolvedPlatform
                Version   = $release.tag_name
                Status    = if($applied -contains $m.Template){ 'Vendored' } else { 'Skipped' }
            }
        }
    }
}
