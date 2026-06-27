BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    # Vendoring runs for real through Add-MOTemplate + the resolvers; only the network seams are mocked.
    $dependencies = @(
        'Invoke-GitHubRest.ps1'
        'Save-GitHubReleaseAsset.ps1'
        'Add-MOTemplate.ps1'
        'Resolve-MOArchetype.ps1'
        'Resolve-MOPlatform.ps1'
        'Resolve-MOTemplateAsset.ps1'
        'Resolve-MOProvisionSplat.ps1'
        'Get-MOProvisionAllowList.ps1'
        'Get-MOTreeHash.ps1'
        'Get-MOTemplateRelease.ps1'
        'Get-MOTemplateManifest.ps1'
        'Read-MOTemplateLock.ps1'
        'Write-MOTemplateLock.ps1'
    )
    $dependencies.ForEach{
        if ($sourceMap.ContainsKey($_)) { . $sourceMap[$_] }
        else { Write-Warning "Dependency not found under source: $_" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Add-MORepoScaffold'
    . $fileName

    # Stub an allow-listed provisioning cmdlet so Get-Command resolves it and Mock can capture the call.
    function Add-MOAzureDevOpsModusBuildValidation {
        param($OrganizationUri, $ProjectName, $RepositoryName, $BuildDefinitionId, $Token)
    }

    $testTempBase = Join-Path $currentPath ".pestertmp_$functionName"
    if (Test-Path $testTempBase) { Remove-Item $testTempBase -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $testTempBase -Force | Out-Null
}

AfterAll {
    if ($testTempBase -and (Test-Path $testTempBase)) { Remove-Item $testTempBase -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Add-MORepoScaffold' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null

        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        Mock Invoke-WebRequest { throw 'No real HTTP in tests' }

        Mock Get-MOTemplateRelease {
            [pscustomobject]@{
                tag_name = 'v1'
                assets   = @(
                    [pscustomobject]@{ name = 'gh.workflow.prValidation.yml';   browser_download_url = 'https://example/gh.workflow.prValidation.yml' }
                    [pscustomobject]@{ name = 'gh.prTemplate.pullRequest.md';    browser_download_url = 'https://example/gh.prTemplate.pullRequest.md' }
                    [pscustomobject]@{ name = 'manifest.json';                   browser_download_url = 'https://example/manifest.json' }
                )
            }
        }
        Mock Get-MOTemplateManifest {
            @{
                templates = @{
                    prValidation = @{
                        category = 'repoScaffold'; kind = @{ gh = 'workflow' }; platforms = @('gh')
                        assets = @{ gh = 'gh.workflow.prValidation.yml' }; dest = @{ gh = '.github/workflows/prValidation.yml' }
                    }
                    pullRequestTemplate = @{
                        category = 'repoScaffold'; kind = @{ gh = 'prTemplate' }; platforms = @('gh')
                        assets = @{ gh = 'gh.prTemplate.pullRequest.md' }; dest = @{ gh = '.github/PULL_REQUEST_TEMPLATE.md' }
                    }
                }
                sets = @{
                    templateLibrary = @{ type = 'archetype'; platforms = @('gh'); steps = @(
                        @{ type = 'file'; template = 'prValidation' }
                        @{ type = 'file'; template = 'pullRequestTemplate' }
                    ) }
                    workflowSet = @{ type = 'selector'; platforms = @('gh'); select = @{ category = 'repoScaffold'; kind = 'workflow' } }
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }
        # Single-file assets (.yml / .md) - write known content to the requested path.
        Mock Save-GitHubReleaseAsset { Set-Content -LiteralPath $Path -Value "content: $([guid]::NewGuid())" -NoNewline }
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'vendors every member to its fixed dest' {
        Add-MORepoScaffold -Archetype templateLibrary -Platform gh -ProjectPath $tmp
        (Test-Path (Join-Path $tmp '.github/workflows/prValidation.yml')) | Should -BeTrue
        (Test-Path (Join-Path $tmp '.github/PULL_REQUEST_TEMPLATE.md'))   | Should -BeTrue
    }

    It 'tags each member in the lockfile with the archetype + version' {
        Add-MORepoScaffold -Archetype templateLibrary -Platform gh -ProjectPath $tmp
        $lock = Get-Content (Join-Path $tmp '.modusops.lock') -Raw | ConvertFrom-Json
        $lock.templates.prValidation.archetype        | Should -Be 'templateLibrary'
        $lock.templates.prValidation.archetypeVersion | Should -Be 'v1'
        $lock.templates.pullRequestTemplate.archetype | Should -Be 'templateLibrary'
    }

    It 'returns one Vendored row per member' {
        $rows = @(Add-MORepoScaffold -Archetype templateLibrary -Platform gh -ProjectPath $tmp)
        $rows.Count | Should -Be 2
        ($rows | Where-Object Name -eq 'prValidation').Status | Should -Be 'Vendored'
    }

    It 'narrows to workflow members with -Include' {
        Add-MORepoScaffold -Archetype templateLibrary -Platform gh -ProjectPath $tmp -Include workflow
        (Test-Path (Join-Path $tmp '.github/workflows/prValidation.yml')) | Should -BeTrue
        (Test-Path (Join-Path $tmp '.github/PULL_REQUEST_TEMPLATE.md'))   | Should -BeFalse
    }

    It 'applies a selector set' {
        Add-MORepoScaffold -Archetype workflowSet -Platform gh -ProjectPath $tmp
        (Test-Path (Join-Path $tmp '.github/workflows/prValidation.yml')) | Should -BeTrue
        (Test-Path (Join-Path $tmp '.github/PULL_REQUEST_TEMPLATE.md'))   | Should -BeFalse
    }

    It 'honours -WhatIf - writes nothing' {
        Add-MORepoScaffold -Archetype templateLibrary -Platform gh -ProjectPath $tmp -WhatIf
        (Test-Path (Join-Path $tmp '.github')) | Should -BeFalse
        (Test-Path (Join-Path $tmp '.modusops.lock')) | Should -BeFalse
    }

    It 'throws for an unknown archetype' {
        { Add-MORepoScaffold -Archetype ghost -Platform gh -ProjectPath $tmp } | Should -Throw '*not in the manifest*'
    }
}

Describe 'Add-MORepoScaffold (provision steps)' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null

        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        Mock Invoke-WebRequest { throw 'No real HTTP in tests' }
        Mock Add-MOAzureDevOpsModusBuildValidation {}   # capture provisioning calls

        Mock Get-MOTemplateRelease {
            [pscustomobject]@{
                tag_name = 'v1'
                assets   = @(
                    [pscustomobject]@{ name = 'azd.registerModusOpsFeeds.yml'; browser_download_url = 'https://example/azd.registerModusOpsFeeds.yml' }
                    [pscustomobject]@{ name = 'manifest.json'; browser_download_url = 'https://example/manifest.json' }
                )
            }
        }
        Mock Get-MOTemplateManifest {
            @{
                templates = @{
                    registerModusOpsFeeds = @{
                        category = 'pipeline'; kind = @{ azd = 'stepTemplate' }; platforms = @('azd')
                        assets = @{ azd = 'azd.registerModusOpsFeeds.yml' }
                    }
                }
                sets = @{
                    azdOps = @{ type = 'archetype'; platforms = @('azd'); steps = @(
                        @{ type = 'file'; template = 'registerModusOpsFeeds' }
                        @{ type = 'provision'; id = 'buildValidation'; cmdlet = 'Add-MOAzureDevOpsModusBuildValidation';
                           with = @{ RepositoryName = '{repo}'; BuildDefinitionId = '{buildId}' } }
                    ) }
                    badProvision = @{ type = 'archetype'; platforms = @('azd'); steps = @(
                        @{ type = 'provision'; cmdlet = 'Remove-Item'; with = @{} }
                    ) }
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }
        Mock Save-GitHubReleaseAsset { Set-Content -LiteralPath $Path -Value "steps:`n  - script: echo hi" -NoNewline }
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'vendors the file member and invokes the provision cmdlet with bound args' {
        Add-MORepoScaffold -Archetype azdOps -Platform azd -OrganizationUri 'https://dev.azure.com/x' `
            -ProjectName 'p' -With @{ repo = 'myRepo'; buildId = 42 } -ProjectPath $tmp
        (Test-Path (Join-Path $tmp 'templates/registerModusOpsFeeds.yml')) | Should -BeTrue
        Should -Invoke Add-MOAzureDevOpsModusBuildValidation -Times 1 -ParameterFilter {
            $RepositoryName -eq 'myRepo' -and $BuildDefinitionId -eq 42 -and $OrganizationUri -eq 'https://dev.azure.com/x'
        }
    }

    It 'writes a provision marker in the lock (cmdlet + archetype, no sha)' {
        Add-MORepoScaffold -Archetype azdOps -Platform azd -OrganizationUri 'https://x' `
            -With @{ repo = 'r'; buildId = 1 } -ProjectPath $tmp
        $lock = Get-Content (Join-Path $tmp '.modusops.lock') -Raw | ConvertFrom-Json
        $entry = $lock.templates.'azdOps:buildValidation'
        $entry.kind      | Should -Be 'provision'
        $entry.cmdlet    | Should -Be 'Add-MOAzureDevOpsModusBuildValidation'
        $entry.archetype | Should -Be 'azdOps'
        $entry.sha256    | Should -BeNullOrEmpty
    }

    It 'requires -OrganizationUri when the archetype has provision steps' {
        { Add-MORepoScaffold -Archetype azdOps -Platform azd -ProjectPath $tmp } | Should -Throw '*OrganizationUri*'
    }

    It 'rejects a provision cmdlet not in the allow-list' {
        { Add-MORepoScaffold -Archetype badProvision -Platform azd -OrganizationUri 'https://x' -ProjectPath $tmp } |
            Should -Throw '*allow-list*'
    }

    It 'honours -WhatIf - invokes nothing and writes no lock' {
        Add-MORepoScaffold -Archetype azdOps -Platform azd -OrganizationUri 'https://x' `
            -With @{ repo = 'r'; buildId = 1 } -ProjectPath $tmp -WhatIf
        Should -Invoke Add-MOAzureDevOpsModusBuildValidation -Times 0
        (Test-Path (Join-Path $tmp '.modusops.lock')) | Should -BeFalse
    }
}
