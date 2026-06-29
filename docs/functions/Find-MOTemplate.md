---
layout: default
title: Find-MOTemplate
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Find-MOTemplate

## SYNOPSIS
Discovers templates available in the modusOps template library (npm-search style).

## SYNTAX

```
Find-MOTemplate [[-Name] <String>] [[-Version] <String>] [[-Platform] <String>] [-AllPlatforms]
 [[-Category] <String>] [[-Kind] <String>] [[-RepoType] <String>] [[-ProjectPath] <String>]
 [[-LockFile] <String>] [[-Source] <String>] [[-Token] <SecureString>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Resolves a release of the template library (latest, or -Version) and reads its manifest.json,
emitting one object per template (name, description, platforms, version, asset).
Optionally
filter by -Name (wildcards) and/or -Platform.
Read-only discovery - nothing is written
locally; use Add-MOTemplate to vendor one.

The Asset field reflects the view: with -Platform it is that platform's single asset; without
it, the full per-platform asset map (so a dual-platform template shows both azd and gh, not
just the first one).

## EXAMPLES

### EXAMPLE 1
```
Find-MOTemplate
```

#### DESCRIPTION
Lists every template in the latest library release.

### EXAMPLE 2
```
Find-MOTemplate -Name 'send*' -Version v0.1.0
```

#### DESCRIPTION
Lists notification templates present in release v0.1.0.

## PARAMETERS

### -Name
Filter to template names (supports wildcards)

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
v0.1.0.
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
Filter to templates that ship the given platform asset.
Omit to default to the repo's platform
(lockfile default / auto-detect) so the catalog shows only what's relevant; pass -AllPlatforms to override.

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
Show every platform's templates instead of defaulting to the repo's resolved platform

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

### -Category
Filter to a category: pipeline (compose into a pipeline) or repoScaffold (repo furniture)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Kind
Filter to a kind, e.g.
workflow / compositeAction / issueTemplate / prTemplate / stepTemplate

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

### -RepoType
Filter to a repo type for repoScaffold assets, e.g.
templatesRepo

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

### -ProjectPath
Consumer repo root (used to resolve the default platform when -Platform is omitted)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
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
Position: 8
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
Position: 9
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
Position: 10
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

