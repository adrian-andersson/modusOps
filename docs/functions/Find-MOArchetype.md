---
layout: default
title: Find-MOArchetype
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Find-MOArchetype

## SYNOPSIS
Discovers the repo-scaffold sets (archetypes) available in the template library.

## SYNTAX

```
Find-MOArchetype [[-Name] <String>] [[-Version] <String>] [[-Platform] <String>] [-AllPlatforms]
 [[-ProjectPath] <String>] [[-LockFile] <String>] [[-Source] <String>] [[-Token] <SecureString>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Resolves a library release, reads its manifest.json, and emits one object per set (name, type,
platforms, member count, description).
A set is a named bundle you apply in one call with
Add-MORepoScaffold.
Member count is resolved against the effective platform (so a 'selector' set
reports how many templates currently match); with -Platform omitted it defaults to the repo's
resolved platform, so the catalog shows only relevant sets (pass -AllPlatforms to override).

## EXAMPLES

### EXAMPLE 1
```
Find-MOArchetype
```

#### DESCRIPTION
Lists every set in the latest library release for the repo's platform.

## PARAMETERS

### -Name
Filter to set names (supports wildcards)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -Version
Release tag to inspect, e.g.
v1.
Omit for the latest release.

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
Filter to sets that support the given platform.
Omit to default to the repo's platform.

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

### -AllPlatforms
Show sets for every platform instead of the repo's resolved platform

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProjectPath
Consumer repo root (used to resolve the default platform when -Platform is omitted)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: .
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
Position: 5
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
Position: 6
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
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Management.Automation.PSObject
## NOTES
Author: Adrian Andersson

## RELATED LINKS

