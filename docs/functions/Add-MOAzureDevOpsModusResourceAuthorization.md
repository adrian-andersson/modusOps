---
layout: default
title: Add-MOAzureDevOpsModusResourceAuthorization
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Add-MOAzureDevOpsModusResourceAuthorization

## SYNOPSIS
Authorizes a pipeline to use another repository as a resource, via the REST Pipeline
Permissions API - removing the first-run "this pipeline needs permission" prompt.

## SYNTAX

```
Add-MOAzureDevOpsModusResourceAuthorization [-OrganizationUri] <String> [-Credential] <PSCredential>
 [-RepositoryName] <String> [-PipelineId] <Int32> [[-ProjectName] <String>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
When a YAML pipeline references another repo (\`resources.repositories\`), Azure DevOps blocks
the first run until the cross-repo access is authorized.
This grants that authorization for a
specific pipeline (not all-pipelines - tighter).
Idempotent: skips if already authorized.

## EXAMPLES

### EXAMPLE 1
```
Add-MOAzureDevOpsModusResourceAuthorization -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat `
    -RepositoryName modusOpsTemplates -PipelineId 73 -Verbose
```

#### DESCRIPTION
Lets pipeline 73 (the modusOps example) check out the modusOpsTemplates repo.

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
The repository resource being authorized (the one referenced by the pipeline)

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

### -PipelineId
The pipeline (build definition) id being granted access

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
Project that owns the repository and pipeline

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
PAT scope: Pipeline Resources (Use and manage).
Resource id for a repository is '{projectId}.{repositoryId}'.

## RELATED LINKS

