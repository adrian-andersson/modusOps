---
layout: default
title: Add-MOTemplate
parent: Functions
external help file: modusOps-help.xml
Module Name: modusOps
online version:
schema: 2.0.0
---

# Add-MOTemplate

## SYNOPSIS
Vendors one or more modusOps pipeline templates from the library into the local repo and pins them.

## SYNTAX

```
Add-MOTemplate [-Name] <String[]> [[-Version] <String>] [[-Platform] <String>] [[-ProjectPath] <String>]
 [[-Path] <String>] [[-LockFile] <String>] [[-Source] <String>] [[-Token] <SecureString>]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
The authoring-time "install" verb (npm-install for templates).
Resolves the named template(s)
in a GitHub release of the template library, downloads each asset, writes it locally under
-Path (vendor-at-fetch), records source URL + version + asset + SHA256 in the consumer's
.modusops.lock, and returns the lock entry per template.

-Name accepts an array, so several templates can be vendored together at the same version in
one call (e.g.
-Name registerModusOpsFeeds,installModusOpsModules).
Every requested name is
resolved against the manifest first - a typo or missing asset throws before anything is
downloaded or written, so a batch can't leave the repo half-applied.
The lockfile is written
once for the whole batch.

Vendored shape follows the asset shape:
  azd (.yml asset)  -\> a single file  templates/\<name\>.yml
  gh  (.zip asset)  -\> a composite-action directory  templates/\<name\>/action.yml (the zip is
                       expanded; the inner action.yml is the file \`uses:\` resolves and the hash
                       pinned in the lockfile).

The vendored file is committed and reviewed in the consumer's own PR; nothing is fetched at
pipeline compile- or run-time.
Always pin a version in practice - omitting -Version takes the
latest release, which is recorded explicitly in the lockfile (never a blind "latest").

## EXAMPLES

### EXAMPLE 1
```
Add-MOTemplate -Name registerModusOpsFeeds -Version v0.1.0
```

#### DESCRIPTION
Vendors templates/registerModusOpsFeeds.yml from release v0.1.0 and records it in .modusops.lock.

#### OUTPUT
The lockfile entry (version, platform, asset, path, sha256, url).

### EXAMPLE 2
```
Add-MOTemplate -Name registerModusOpsFeeds,installModusOpsModules,sendDiscordChannelMessage -Version v1
```

#### DESCRIPTION
Vendors all three templates from release v1 in one call, pinning each in .modusops.lock.

#### OUTPUT
One lockfile entry per template.

## PARAMETERS

### -Name
Template name(s) as listed in the library manifest - one or more, vendored together at the same version.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Version
Release tag to pull, e.g.
v0.1.0.
Omit for the latest release (recorded explicitly).

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

### -Platform
Target platform asset to vendor.
Omit to resolve it (lockfile default, else repo-shape detection).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
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
Position: 4
Default value: .
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
Templates directory (relative to ProjectPath) to write the vendored file into

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: Templates
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
Position: 6
Default value: .modusops.lock
Accept pipeline input: False
Accept wildcard characters: False
```

### -Source
Template library GitHub repo URL (override for an internal mirror/fork)

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: Https://github.com/adrian-andersson/modusops-templates
Accept pipeline input: False
Accept wildcard characters: False
```

### -Token
Optional GitHub token (raises rate limit / reaches private mirrors)

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
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

### System.Management.Automation.PSObject[]
## NOTES
Author: Adrian Andersson

## RELATED LINKS

