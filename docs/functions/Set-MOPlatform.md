---
layout: default
title: Set-MOPlatform
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Set-MOPlatform

## SYNOPSIS
Sets the default Platform Type (azd|gh) for the repo so commands stop re-taking -Platform.

## SYNTAX

```
Set-MOPlatform [-Platform] <String> [-ProjectPath <String>] [-LockFile <String>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Writes defaults.platform into the consumer's .modusops.lock (creating the lock if absent).
Once
set, Find/Add/Update/Get-MOTemplate and the scaffold cmdlets resolve the platform from here via
Resolve-MOPlatform, so you only pass -Platform to override.
The first Add-MOTemplate also seeds
this automatically from what it resolved - Set-MOPlatform is for setting or changing it explicitly.

## EXAMPLES

### EXAMPLE 1
```
Set-MOPlatform gh
```

#### DESCRIPTION
Records gh as the repo default in ./.modusops.lock.

#### OUTPUT
{ Platform = gh; Source = lockfile }

## PARAMETERS

### -Platform
The default platform to record

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

### -ProjectPath
Consumer repo root holding the lockfile

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
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
Position: Named
Default value: .modusops.lock
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

### System.Management.Automation.PSObject
## NOTES
Author: Adrian Andersson

## RELATED LINKS

