---
layout: default
title: New-MOAzureDevOpsModusPipeline
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# New-MOAzureDevOpsModusPipeline

## SYNOPSIS
Creates an Azure DevOps YAML pipeline pointing at a file in a repository, via the REST API.

## SYNTAX

```
New-MOAzureDevOpsModusPipeline [-OrganizationUri] <String> [-Credential] <PSCredential>
 [-RepositoryName] <String> [-Name] <String> [-YamlPath] <String> [[-ProjectName] <String>]
 [[-Folder] <String>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Idempotent: if a pipeline with the same name already exists it is returned, not recreated.
The created pipeline adopts whatever \`trigger:\` the referenced YAML declares.

## EXAMPLES

### EXAMPLE 1
```
New-MOAzureDevOpsModusPipeline -OrganizationUri 'https://dev.azure.com/myorg' -Credential $pat `
    -RepositoryName modusOpsTemplates -Name 'modusOpsTemplates Tag On Merge' -YamlPath '/ci/tagOnMerge.yml' -Verbose
```

#### DESCRIPTION
Creates (or returns) the tag-on-merge pipeline for the templates repo.

#### OUTPUT
The pipeline object (includes \`id\`, which equals the build-definition id).

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
Repository that holds the YAML

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

### -Name
Pipeline display name

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

### -YamlPath
Repo-relative path to the YAML, e.g.
/ci/tagOnMerge.yml

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProjectName
Project that owns the repository / pipeline

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: ModusOps
Accept pipeline input: False
Accept wildcard characters: False
```

### -Folder
Pipeline folder

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: \
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
PAT scope: Build (Read & execute) / Edit build pipeline.

## RELATED LINKS

