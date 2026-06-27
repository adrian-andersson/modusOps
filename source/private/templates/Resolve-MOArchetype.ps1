function Resolve-MOArchetype
{
    <#
        .SYNOPSIS
            Expands a named set (archetype) from a library manifest into its ordered member templates.

        .DESCRIPTION
            The pure expansion seam behind Add-MORepoScaffold / Find-MOArchetype. Given a parsed manifest, a
            set name and the target platform, returns one descriptor per member (Template, Category, Kind) in
            apply order. Two set shapes:

              type 'archetype' - a curated, ordered list of steps. 'file' steps name a member template (vendored);
                                 'provision' steps name a scaffold cmdlet + a with-map (a REST action, e.g.
                                 a branch policy). Both are returned with a StepType so the caller dispatches.
              type 'selector'  - a derived query: every template whose category (and kind, for the platform)
                                 match `select`, minus anything in `exclude`, sorted by name. Evaluated against
                                 THIS manifest version - immutable + lock-pinned, so it stays deterministic.

            -Include narrows the result to members of the given kind(s). No network: the caller supplies the
            already-resolved manifest object.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([psobject[]])]
    PARAM(
        #Parsed manifest (as returned by Get-MOTemplateManifest)
        [Parameter(Mandatory)]
        [PSCustomObject]$Manifest,
        #Set / archetype name to expand
        [Parameter(Mandatory)]
        [string]$Archetype,
        #Target platform - selects each member's per-platform kind/asset
        [Parameter(Mandatory)]
        [ValidateSet('azd','gh')]
        [string]$Platform,
        #Narrow to members of these kind(s), e.g. workflow
        [string[]]$Include
    )
    process{
        if(-not $Manifest.sets){ throw "The manifest has no 'sets' (archetypes)." }
        $setProp = $Manifest.sets.PSObject.Properties | Where-Object { $_.Name -eq $Archetype } | Select-Object -First 1
        if(-not $setProp){ throw "Archetype '$Archetype' is not in the manifest." }
        $set = $setProp.Value

        if($set.platforms -and (@($set.platforms) -notcontains $Platform)){
            throw "Archetype '$Archetype' does not support platform '$Platform' (supports: $(@($set.platforms) -join ', '))."
        }

        $type = if($set.type){ [string]$set.type } else { 'archetype' }
        $members = [System.Collections.Generic.List[object]]::new()

        if($type -eq 'selector'){
            $sel = $set.select
            foreach($prop in $Manifest.templates.PSObject.Properties){
                $t = $prop.Value
                $cat = if($t.category){ [string]$t.category } else { 'pipeline' }
                if($sel.category -and $cat -ne [string]$sel.category){ continue }
                $kind = if($t.kind){ [string]$t.kind.$Platform } else { $null }
                if($sel.kind -and $kind -ne [string]$sel.kind){ continue }
                if(@($t.platforms) -notcontains $Platform){ continue }
                if($set.exclude -and (@($set.exclude) -contains $prop.Name)){ continue }
                $members.Add([pscustomobject]@{ StepType = 'file'; Template = $prop.Name; Category = $cat; Kind = $kind })
            }
            $ordered = @($members | Sort-Object Template)
        }else{
            $ordered = [System.Collections.Generic.List[object]]::new()
            foreach($step in @($set.steps)){
                $stype = if($step.type){ [string]$step.type } else { 'file' }

                if($stype -eq 'provision'){
                    if([string]::IsNullOrWhiteSpace($step.cmdlet)){ throw "Archetype '$Archetype' has a provision step with no cmdlet." }
                    $withMap = @{}
                    if($step.with){ foreach($p in $step.with.PSObject.Properties){ $withMap[$p.Name] = $p.Value } }
                    $id = if($step.id){ [string]$step.id } else { [string]$step.cmdlet }
                    $ordered.Add([pscustomobject]@{
                        StepType = 'provision'; Name = $id; Cmdlet = [string]$step.cmdlet; With = $withMap
                        Template = $null; Category = $null; Kind = $null
                    })
                    continue
                }

                if($stype -ne 'file'){ throw "Archetype '$Archetype' has an unknown step type '$stype'." }
                $name = [string]$step.template
                $tProp = $Manifest.templates.PSObject.Properties | Where-Object { $_.Name -eq $name } | Select-Object -First 1
                if(-not $tProp){ throw "Archetype '$Archetype' references unknown template '$name'." }
                $t = $tProp.Value
                if(@($t.platforms) -notcontains $Platform){
                    Write-Warning "Archetype '$Archetype': member '$name' has no '$Platform' asset; skipping."
                    continue
                }
                $cat = if($t.category){ [string]$t.category } else { 'pipeline' }
                $kind = if($t.kind){ [string]$t.kind.$Platform } else { $null }
                $ordered.Add([pscustomobject]@{ StepType = 'file'; Template = $name; Category = $cat; Kind = $kind })
            }
            $ordered = @($ordered)
        }

        if($Include){
            #Narrow to file members of the requested kind(s); provision steps are dropped by a kind filter.
            $ordered = @($ordered | Where-Object { $_.StepType -eq 'file' -and $Include -contains $_.Kind })
        }
        #Cast to PSCustomObject[] so the element type matches the declared OutputType.
        return [pscustomobject[]]$ordered
    }
}
