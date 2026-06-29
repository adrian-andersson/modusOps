---
layout: default
title: Update-MOTemplate
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Update-MOTemplate

## SYNOPSIS
Re-pulls vendored templates at a newer library version, overwriting only what changed.

## SYNTAX

```
Update-MOTemplate [[-Name] <String>] [[-Version] <String>] [[-ProjectPath] <String>] [[-LockFile] <String>]
 [[-Source] <String>] [[-Token] <SecureString>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
The npm-update verb.
For each installed template (all, or -Name), resolves the target release
(latest, or -Version), downloads the asset, and compares its SHA256 to the lockfile pin:
  - hash changed  -\> overwrites the local file and updates the lockfile (Status 'Changed')
  - hash unchanged -\> leaves the file untouched, only re-pins the version (Status 'Unchanged')
So the version coordinate always advances but the working-tree diff shows only real changes.
Vendored files are a managed directory (node_modules model) - local edits are not preserved.

## EXAMPLES

### EXAMPLE 1
```
Update-MOTemplate -Version v0.2.0
```

#### DESCRIPTION
Re-pins every installed template to v0.2.0, rewriting only those whose bytes changed.

## PARAMETERS

### -Name
Template name to update (supports wildcards).
Omit to update every installed template.

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
Target release tag, e.g.
v0.2.0.
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

### -ProjectPath
Consumer repo root holding the templates dir and lockfile

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
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
Position: 4
Default value: .modusops.lock
Accept pipeline input: False
Accept wildcard characters: False
```

### -Source
Template library GitHub repo URL.
Defaults to the source recorded in the lockfile.

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

### -Token
Optional GitHub token

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
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

### System.Management.Automation.PSObject
## NOTES
Author: Adrian Andersson

## RELATED LINKS

