---
layout: default
title: Get-MOPlatform
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Get-MOPlatform

## SYNOPSIS
Reports the effective default Platform Type (azd|gh) and where it was resolved from.

## SYNTAX

```
Get-MOPlatform [[-ProjectPath] <String>] [[-LockFile] <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Non-throwing companion to Set-MOPlatform.
Returns the resolved platform plus its Source rung:
  lockfile  - read from defaults.platform (set via Set-MOPlatform or seeded by the first Add)
  detected  - inferred from repo shape (.github/ =\> gh ; azure-pipelines.yml =\> azd)
  unset     - could not be determined (ambiguous or empty repo); Platform is $null
Unlike Resolve-MOPlatform (the internal seam, which throws when it can't decide) this never
throws, so it is safe for "what would the tooling use here?" checks.

## EXAMPLES

### EXAMPLE 1
```
Get-MOPlatform
```

#### OUTPUT
{ Platform = gh; Source = lockfile }

## PARAMETERS

### -ProjectPath
Consumer repo root holding the lockfile

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
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
Position: 2
Default value: .modusops.lock
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

