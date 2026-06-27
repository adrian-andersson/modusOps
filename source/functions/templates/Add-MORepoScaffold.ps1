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

        .EXAMPLE
            Add-MORepoScaffold -Archetype azdOpsRepo -OrganizationUri https://dev.azure.com/contoso `
              -ProjectName modusOps -Token $pat -With @{ repo = 'modusOpsTemplates'; buildId = 42 }

            #### DESCRIPTION
            Vendors the set's file members AND runs its provision steps (branch policy, repo permission) - each
            provision cmdlet is validated against the allow-list, then bound from -With + the shared context.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([psobject[]])]
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
        #Azure DevOps organization URL - required when the archetype has provision steps
        [string]$OrganizationUri,
        #Azure DevOps project name - threaded to provision cmdlets that accept it
        [string]$ProjectName,
        #Placeholder values for provision steps, e.g. @{ repo = 'modusOps'; buildId = 42 }
        [hashtable]$With = @{},
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

        $provisionMembers = @($members | Where-Object { $_.StepType -eq 'provision' })
        if($provisionMembers.Count -gt 0 -and [string]::IsNullOrWhiteSpace($OrganizationUri)){
            throw "Archetype '$Archetype' has $($provisionMembers.Count) provision step(s); -OrganizationUri is required (and usually -ProjectName)."
        }
        Write-Verbose "Archetype '$Archetype' -> $($members.Count) step(s)"

        $allow   = Get-MOProvisionAllowList
        $context = @{ OrganizationUri = $OrganizationUri; ProjectName = $ProjectName }
        if($Token){ $context.Token = $Token }

        $appliedFiles      = [System.Collections.Generic.List[string]]::new()
        $appliedProvisions = [System.Collections.Generic.List[object]]::new()
        $results           = [System.Collections.Generic.List[object]]::new()

        foreach($m in $members){
            if($m.StepType -eq 'file'){
                #Vendor at the SAME pinned version so the set is consistent. Add-MOTemplate does the per-member
                #work (dest, hashing, lockfile) and inherits -WhatIf. (It re-resolves the release per call - fine
                #for now; a shared pre-resolved seam would remove the extra fetches.)
                $addSplat = @{
                    Name = $m.Template; Platform = $resolvedPlatform; Version = $release.tag_name
                    ProjectPath = $ProjectPath; Path = $Path; LockFile = $LockFile; Source = $Source
                } + $tokenSplat
                $res = Add-MOTemplate @addSplat
                $status = if($res){ $appliedFiles.Add($m.Template); 'Vendored' } else { 'Skipped' }
                $results.Add([pscustomobject]@{ Archetype = $Archetype; Step = 'file'; Name = $m.Template; Detail = $m.Kind; Platform = $resolvedPlatform; Version = $release.tag_name; Status = $status })
            }else{
                #Provision: gate on the allow-list (the manifest is privileged input - no arbitrary invocation),
                #bind args (placeholders + context), then invoke through ShouldProcess so -WhatIf previews it.
                if($allow -notcontains $m.Cmdlet){
                    throw "Archetype '$Archetype' provision step '$($m.Name)' names cmdlet '$($m.Cmdlet)', which is not in the provisioning allow-list."
                }
                $cmd = Get-Command -Name $m.Cmdlet -ErrorAction Stop
                $splat = Resolve-MOProvisionSplat -With $m.With -Values $With -Context $context -AcceptedParameters @($cmd.Parameters.Keys)
                $status = 'Skipped'
                if($PSCmdlet.ShouldProcess("$($m.Cmdlet) [$($m.Name)]", 'Provision')){
                    & $cmd @splat | Out-Null
                    $appliedProvisions.Add([pscustomobject]@{ Name = $m.Name; Cmdlet = $m.Cmdlet })
                    $status = 'Applied'
                }
                $results.Add([pscustomobject]@{ Archetype = $Archetype; Step = 'provision'; Name = $m.Name; Detail = $m.Cmdlet; Platform = $resolvedPlatform; Version = $release.tag_name; Status = $status })
            }
        }

        #Record membership: tag vendored files; write a marker per applied provision (no SHA - it's a REST
        #action, not a file, so Test-MOTemplate skips it). Skipped entirely under -WhatIf (nothing applied).
        if($appliedFiles.Count -gt 0 -or $appliedProvisions.Count -gt 0){
            $lock = Read-MOTemplateLock -Path $lockPath
            foreach($name in $appliedFiles){
                if($lock.templates.ContainsKey($name)){
                    $lock.templates[$name].archetype        = $Archetype
                    $lock.templates[$name].archetypeVersion = $release.tag_name
                }
            }
            foreach($p in $appliedProvisions){
                $lock.templates["$Archetype`:$($p.Name)"] = @{
                    kind             = 'provision'
                    cmdlet           = $p.Cmdlet
                    archetype        = $Archetype
                    archetypeVersion = $release.tag_name
                }
            }
            Write-MOTemplateLock -Lock $lock -Path $lockPath
        }

        #Return as PSCustomObject[] so the element type matches the declared OutputType.
        return [pscustomobject[]]$results
    }
}
