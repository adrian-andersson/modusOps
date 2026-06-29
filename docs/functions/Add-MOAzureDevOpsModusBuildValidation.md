---
layout: default
title: Add-MOAzureDevOpsModusBuildValidation
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Add-MOAzureDevOpsModusBuildValidation

## SYNOPSIS
Adds a build-validation branch policy on a repository branch, via the REST Policy API.

## SYNTAX

```
Add-MOAzureDevOpsModusBuildValidation [-OrganizationUri] <String> [-Credential] <PSCredential>
 [-RepositoryName] <String> [-BuildDefinitionId] <Int32> [[-ProjectName] <String>] [[-Branch] <String>]
 [[-DisplayName] <String>] [[-Blocking] <Boolean>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Wires a pipeline (build definition) as a PR build-validation policy on a branch - e.g.
the
prValidation pipeline as a required check on \`main\`.
Idempotent: skips if a build policy for
the same definition already exists on that branch.

## EXAMPLES

### EXAMPLE 1
```
Add-MOAzureDevOpsModusBuildValidation -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat `
    -RepositoryName modusOpsTemplates -BuildDefinitionId 42 -DisplayName 'PR Validation' -Verbose
```

#### DESCRIPTION
Makes build definition 42 a required PR check on modusOpsTemplates/main.

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
Repository the policy applies to

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

### -BuildDefinitionId
Build definition / pipeline id to run as the check

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: 0
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

### -Branch
Branch ref the policy applies to

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: Refs/heads/main
Accept pipeline input: False
Accept wildcard characters: False
```

### -DisplayName
Policy display name

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: PR Validation
Accept pipeline input: False
Accept wildcard characters: False
```

### -Blocking
Block the merge on failure (required vs optional)

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: True
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
PAT scope: Code (Read, write & manage) - policies are a Code-manage operation.
Build-policy type id is the well-known '0609b952-1397-4640-95ec-e00a01b2c241'.

## RELATED LINKS

