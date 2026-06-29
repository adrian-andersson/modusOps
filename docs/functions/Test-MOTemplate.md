---
layout: default
title: Test-MOTemplate
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Test-MOTemplate

## SYNOPSIS
Offline integrity check of vendored templates against the lockfile (npm-ci style).

## SYNTAX

```
Test-MOTemplate [[-Name] <String>] [[-ProjectPath] <String>] [[-LockFile] <String>] [-CheckUpdate]
 [[-Source] <String>] [[-Token] <SecureString>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
For each template in .modusops.lock, recomputes the local file's SHA256 and compares it to the
pinned hash.
Reports one object per template (Name, Status, Version, Path, Expected, Actual) with
a Status of:
  OK       - file present and hash matches the lockfile
  Drifted  - file present but hash differs (locally edited; vendored files are managed)
  Missing  - lockfile entry has no corresponding local file
Provision markers (archetype REST actions) are skipped - there is no file to hash.
No network
access by default, so it is a cheap CI gate.

-CheckUpdate additionally queries the library once for the latest release and annotates each row
with Latest + UpdateAvailable (this is the only path that touches the network).

## EXAMPLES

### EXAMPLE 1
```
Test-MOTemplate
```

#### DESCRIPTION
Verifies every vendored template under ./ against ./.modusops.lock (offline).

### EXAMPLE 2
```
Test-MOTemplate -CheckUpdate
```

#### DESCRIPTION
As above, plus a Latest / UpdateAvailable column showing whether a newer library version exists.

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
Consumer repo root holding the lockfile and templates

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

### -CheckUpdate
Also query the library for the latest version (online) and add Latest + UpdateAvailable columns

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

### -Source
Template library URL for -CheckUpdate (defaults to the lockfile's recorded source)

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

### -Token
Optional GitHub token for -CheckUpdate

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
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

