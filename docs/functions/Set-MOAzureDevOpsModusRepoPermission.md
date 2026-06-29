---
layout: default
title: Set-MOAzureDevOpsModusRepoPermission
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Set-MOAzureDevOpsModusRepoPermission

## SYNOPSIS
Grants an identity (default: the project Build Service) repository permissions via the
Security ACL API - so CI pipelines can push tags and post PR comments.

## SYNTAX

```
Set-MOAzureDevOpsModusRepoPermission [-OrganizationUri] <String> [-Credential] <PSCredential>
 [-RepositoryName] <String> [[-ProjectName] <String>] [[-IdentityName] <String>] [[-Allow] <Int32>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Resolves the project, repository, and identity, then sets an allow ACE on the Git
Repositories security namespace for token \`repoV2/{projectId}/{repoId}\`.
Uses \`merge\` so
existing permissions are preserved; re-running is safe (sets the same allow bits).

Default allow bits - Contribute (4) + PullRequestContribute (16384) = 16388 - are exactly
what \`tagOnMerge\` (push a tag) and \`prValidation\` (post a PR comment) need.

## EXAMPLES

### EXAMPLE 1
```
Set-MOAzureDevOpsModusRepoPermission -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat `
    -RepositoryName modusOpsTemplates -Verbose
```

#### DESCRIPTION
Grants 'modusOps Build Service (myorg)' Contribute + Contribute-to-PRs on the repo.

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
Repository to set the permission on

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

### -ProjectName
Project that owns the repository

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

### -IdentityName
Identity to grant.
Defaults to the project Build Service.

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

### -Allow
Allow bitmask.
Default Contribute(4) + PullRequestContribute(16384) = 16388

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: 16388
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

## NOTES
Author: Adrian Andersson
PAT scope: Code (Read, write & manage) - managing permissions is a Code-manage operation.
Git Repositories security namespace id: 2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87.
Git permission bits: Contribute=4, PullRequestContribute=16384 (combined allow = 16388).

## RELATED LINKS

