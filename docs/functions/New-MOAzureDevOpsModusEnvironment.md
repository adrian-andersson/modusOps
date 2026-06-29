---
layout: default
title: New-MOAzureDevOpsModusEnvironment
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# New-MOAzureDevOpsModusEnvironment

## SYNOPSIS
Scaffolds the modusOps control-plane in an Azure DevOps organisation - project, repositories,
and an Azure Artifacts feed - using only PowerShell and the Azure DevOps REST API.

## SYNTAX

```
New-MOAzureDevOpsModusEnvironment [-OrganizationUri] <String> [-Credential] <PSCredential>
 [[-ProjectName] <String>] [[-FeedName] <String>] [[-Repository] <String[]>] [[-ProcessName] <String>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Idempotent "get-or-create": every resource is checked before it is created, so it can be
re-run safely.
Authenticates with a PAT supplied as a PSCredential (the PAT is the password;
the username is ignored).

Creates, in order:
  1.
the project (async - the operation is polled to completion)
  2.
the requested git repositories
  3.
the Azure Artifacts feed
  4.
(best-effort) grants the project Build Service 'reader' on the feed

## EXAMPLES

### EXAMPLE 1
```
$pat = Get-Credential -UserName 'pat' -Message 'Azure DevOps PAT'
New-MOAzureDevOpsModusEnvironment -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat -Verbose
```

#### DESCRIPTION
Creates (or confirms) the project, repositories, and feed.

#### OUTPUT
A summary object listing the organisation, project, feed, and repositories.

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

### -ProjectName
Project to create / use

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: ModusOps
Accept pipeline input: False
Accept wildcard characters: False
```

### -FeedName
Azure Artifacts feed to create / use

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: ModusOps
Accept pipeline input: False
Accept wildcard characters: False
```

### -Repository
Repositories to create in the project.
Default: the operations repo only - templates are
vendored from the GitHub library (Add-MOTemplate), not provisioned as an AZD repo, and the
Toolkit/business modules are consumed from the feed.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: @('modusOps')
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProcessName
Process template for a new project

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: Basic
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
PAT scopes: Project and Team (Read, write & manage), Code (Read, write & manage),
Packaging (Read, write & manage), Identity (Read).
Only the modern 'https://dev.azure.com/{org}' URI form is handled (not legacy *.visualstudio.com).

## RELATED LINKS

