---
layout: default
title: Push-MOAzureDevOpsModusContent
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Push-MOAzureDevOpsModusContent

## SYNOPSIS
Pushes a folder of content into an Azure DevOps git repository as an initial commit, via the
REST Git Pushes API.

## SYNTAX

```
Push-MOAzureDevOpsModusContent [-OrganizationUri] <String> [-Credential] <PSCredential>
 [-RepositoryName] <String> [-SourcePath] <String> [[-ProjectName] <String>] [[-Exclude] <String[]>]
 [[-Comment] <String>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
For an EMPTY repository, creates refs/heads/main with one commit containing every file under
-SourcePath (recursive, relative paths preserved), then sets main as the default branch.

Idempotent / safe: if the repo already has commits it is skipped, never clobbered.

Text files only (rawtext content); binary files would need base64 handling - not implemented.

A pure "seed an empty repo from a folder" primitive: the scaffold flow stages the operations
repo's content (templates vendored from the GitHub library via Add-MOTemplate, plus a starter
pipeline) into a working dir, then points -SourcePath at it.

## EXAMPLES

### EXAMPLE 1
```
Push-MOAzureDevOpsModusContent -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat -RepositoryName modusOps -SourcePath $staging -Verbose
```

#### DESCRIPTION
Seeds the (empty) 'modusOps' operations repo with the staged content under $staging.

#### OUTPUT
A summary object with the repository, file count, and branch.

## PARAMETERS

### -OrganizationUri
Organisation URI, e.g.
https://dev.azure.com/myorg

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

### -Credential
PAT credential - the PAT is the password (username is ignored)

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RepositoryName
Repository to push into

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SourcePath
Folder whose contents are pushed as the initial commit (recursive, relative paths preserved)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProjectName
Project that owns the repository

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: ModusOps
Accept pipeline input: False
Accept wildcard characters: False
```

### -Exclude
Wildcard patterns matched against full file paths to skip

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Comment
Commit message

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: Bootstrap modusOps content
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
PAT scope: Code (Read, write, & manage).

## RELATED LINKS

