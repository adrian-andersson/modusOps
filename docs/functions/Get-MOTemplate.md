---
layout: default
title: Get-MOTemplate
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Get-MOTemplate

## SYNOPSIS
Lists the modusOps templates vendored into the consumer repo (reads .modusops.lock).

## SYNTAX

```
Get-MOTemplate [[-Name] <String>] [[-ProjectPath] <String>] [[-LockFile] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Offline.
Reads the lockfile and emits one object per installed template (name, version,
platform, path, sha256, source).
Optionally filter by -Name.
No network access.

## EXAMPLES

### EXAMPLE 1
```
Get-MOTemplate
```

#### DESCRIPTION
Lists everything pinned in ./.modusops.lock.

## PARAMETERS

### -Name
Filter to a single template name (supports wildcards)

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

### -ProjectPath
Consumer repo root holding the lockfile

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
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
Position: 3
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

