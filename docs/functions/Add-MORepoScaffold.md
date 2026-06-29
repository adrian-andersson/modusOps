---
layout: default
title: Add-MORepoScaffold
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Add-MORepoScaffold

## SYNOPSIS
Stamps a whole set (archetype) of templates into a repo in one call, and pins each member.

## SYNTAX

```
Add-MORepoScaffold [-Archetype] <String> [[-Version] <String>] [[-Platform] <String>] [[-Include] <String[]>]
 [[-OrganizationUri] <String>] [[-ProjectName] <String>] [[-With] <Hashtable>] [[-ProjectPath] <String>]
 [[-Path] <String>] [[-LockFile] <String>] [[-Source] <String>] [[-Token] <SecureString>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The scaffold "one-liner": where Add-MOTemplate vendors a single asset, Add-MORepoScaffold expands a
named set from the library manifest and vendors every member, pinning each in .modusops.lock tagged
with the archetype + the version it came from.
Members vendor exactly like Add-MOTemplate (repoScaffold
members land at their fixed dest under .github/; pipeline members in the templates dir), all at one
pinned library version so the set is internally consistent.

Set membership is resolved against the chosen release's manifest (curated steps or a derived selector),
so it is reproducible from (version + set name).
Re-running at a newer -Version re-applies the set,
overwriting changed members (managed-directory / node_modules model) - that is also the update path.

## EXAMPLES

### EXAMPLE 1
```
Add-MORepoScaffold -Archetype templateLibrary
```

#### DESCRIPTION
Vendors every member of the templateLibrary set at the latest release into the repo and records them
in .modusops.lock under that archetype.

### EXAMPLE 2
```
Add-MORepoScaffold -Archetype templateLibrary -Include workflow -WhatIf
```

#### DESCRIPTION
Previews vendoring just the workflow members of the set; downloads and writes nothing.

### EXAMPLE 3
```
Add-MORepoScaffold -Archetype azdOpsRepo -OrganizationUri https://dev.azure.com/contoso `
  -ProjectName modusOps -Token $pat -With @{ repo = 'modusOpsTemplates'; buildId = 42 }
```

#### DESCRIPTION
Vendors the set's file members AND runs its provision steps (branch policy, repo permission) - each
provision cmdlet is validated against the allow-list, then bound from -With + the shared context.

## PARAMETERS

### -Archetype
Set / archetype name (see Find-MOArchetype)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Version
Release tag to pull, e.g.
v1.
Omit for the latest release (recorded explicitly).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Platform
Target platform.
Omit to resolve it (lockfile default, else repo-shape detection).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Include
Narrow to members of these kind(s), e.g.
workflow

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OrganizationUri
Azure DevOps organization URL - required when the archetype has provision steps

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProjectName
Azure DevOps project name - threaded to provision cmdlets that accept it

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -With
Placeholder values for provision steps, e.g.
@{ repo = 'modusOps'; buildId = 42 }

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: @{}
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProjectPath
Consumer repo root holding the templates dir and lockfile

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: .
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
Templates directory (relative to ProjectPath) for any pipeline-category members

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: Templates
Accept pipeline input: False
Accept wildcard characters: False
```

### -LockFile
Lockfile name (relative to ProjectPath)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: .modusops.lock
Accept pipeline input: False
Accept wildcard characters: False
```

### -Source
Template library GitHub repo URL (override for an internal mirror/fork)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: Https://github.com/adrian-andersson/modusops-templates
Accept pipeline input: False
Accept wildcard characters: False
```

### -Token
Optional GitHub token

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 12
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Management.Automation.PSObject[]
## NOTES
Author: Adrian Andersson

## RELATED LINKS

