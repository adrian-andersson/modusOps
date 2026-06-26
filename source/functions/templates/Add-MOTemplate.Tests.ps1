BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    # Resolvers + seams are dot-sourced then mocked; lockfile helpers are left real (pure file I/O on a repo-local temp).
    $dependencies = @(
        'Invoke-GitHubRest.ps1'
        'Save-GitHubReleaseAsset.ps1'
        'Resolve-MOTemplateAsset.ps1'
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
    $functionName = 'Add-MOTemplate'
    . $fileName

    # Repo-local scratch dir (works in any environment, unlike Pester's $TestDrive under our CI runner).
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

Describe 'Add-MOTemplate' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null

        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        Mock Invoke-WebRequest { throw 'No real HTTP in tests' }

        Mock Get-MOTemplateRelease {
            [pscustomobject]@{
                tag_name = 'v0.1.0'
                assets   = @(
                    [pscustomobject]@{ name = 'azd.registerModusOpsFeeds.yml'; browser_download_url = 'https://example/azd.registerModusOpsFeeds.yml' }
                    [pscustomobject]@{ name = 'manifest.json'; browser_download_url = 'https://example/manifest.json' }
                )
            }
        }
        Mock Get-MOTemplateManifest {
            @{
                templates = @{ registerModusOpsFeeds = @{ platforms = @('azd'); assets = @{ azd = 'azd.registerModusOpsFeeds.yml' } } }
            } | ConvertTo-Json -Depth 6 | ConvertFrom-Json
        }
        # Simulate the download by writing known YAML to the destination path.
        Mock Save-GitHubReleaseAsset { Set-Content -LiteralPath $Path -Value "steps:`n  - script: echo hi" -NoNewline }
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'vendors the template file under the templates dir' {
        Add-MOTemplate -Name registerModusOpsFeeds -ProjectPath $tmp
        (Test-Path (Join-Path $tmp 'templates/registerModusOpsFeeds.yml')) | Should -BeTrue
    }

    It 'records the entry with a SHA256 in the lockfile' {
        Add-MOTemplate -Name registerModusOpsFeeds -ProjectPath $tmp
        $lockPath = Join-Path $tmp '.modusops.lock'
        (Test-Path $lockPath) | Should -BeTrue
        $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
        $lock.source | Should -Be 'https://github.com/adrian-andersson/modusops-templates'
        $entry = $lock.templates.registerModusOpsFeeds
        $entry.version | Should -Be 'v0.1.0'
        $entry.platform | Should -Be 'azd'
        $entry.path | Should -Be 'templates/registerModusOpsFeeds.yml'
        $entry.sha256 | Should -Match '^[0-9A-F]{64}$'
        $entry.url | Should -Be 'https://example/azd.registerModusOpsFeeds.yml'
    }

    It 'returns the lock entry including the name' {
        $result = Add-MOTemplate -Name registerModusOpsFeeds -ProjectPath $tmp
        $result.name | Should -Be 'registerModusOpsFeeds'
        $result.version | Should -Be 'v0.1.0'
    }

    It 'throws when the template is not in the manifest' {
        { Add-MOTemplate -Name ghostTemplate -ProjectPath $tmp } | Should -Throw '*not in the manifest*'
    }

    It 'throws when the requested platform has no asset' {
        { Add-MOTemplate -Name registerModusOpsFeeds -Platform gh -ProjectPath $tmp } | Should -Throw "*no 'gh' asset*"
    }

    It 'honours -WhatIf - downloads nothing and writes no lockfile' {
        Add-MOTemplate -Name registerModusOpsFeeds -ProjectPath $tmp -WhatIf
        Should -Invoke Save-GitHubReleaseAsset -Times 0
        (Test-Path (Join-Path $tmp '.modusops.lock')) | Should -BeFalse
    }
}

Describe 'Add-MOTemplate (gh composite action)' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $script:tmp = $tmp

        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        Mock Invoke-WebRequest { throw 'No real HTTP in tests' }

        Mock Get-MOTemplateRelease {
            [pscustomobject]@{
                tag_name = 'v0.1.0'
                assets   = @(
                    [pscustomobject]@{ name = 'gh.registerModusOpsFeeds.zip'; browser_download_url = 'https://example/gh.registerModusOpsFeeds.zip' }
                    [pscustomobject]@{ name = 'manifest.json'; browser_download_url = 'https://example/manifest.json' }
                )
            }
        }
        Mock Get-MOTemplateManifest {
            @{
                templates = @{ registerModusOpsFeeds = @{ platforms = @('gh'); assets = @{ gh = 'gh.registerModusOpsFeeds.zip' } } }
            } | ConvertTo-Json -Depth 6 | ConvertFrom-Json
        }
        $script:actionContent = "name: 'Register'`nruns:`n  using: composite"
        # Simulate the zip download by building a real archive containing action.yml.
        Mock Save-GitHubReleaseAsset {
            $src = Join-Path $script:tmp ('src' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $src -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $src 'action.yml') -Value $script:actionContent -NoNewline
            Compress-Archive -Path (Join-Path $src '*') -DestinationPath $Path -Force
        }
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'vendors the gh template as <name>/action.yml' {
        Add-MOTemplate -Name registerModusOpsFeeds -Platform gh -ProjectPath $tmp
        $actionPath = Join-Path $tmp 'templates/registerModusOpsFeeds/action.yml'
        (Test-Path $actionPath) | Should -BeTrue
        (Get-Content $actionPath -Raw) | Should -Match 'using: composite'
    }

    It 'records the action.yml path + zip asset + sha in the lockfile' {
        Add-MOTemplate -Name registerModusOpsFeeds -Platform gh -ProjectPath $tmp
        $lock = Get-Content (Join-Path $tmp '.modusops.lock') -Raw | ConvertFrom-Json
        $entry = $lock.templates.registerModusOpsFeeds
        $entry.platform | Should -Be 'gh'
        $entry.asset    | Should -Be 'gh.registerModusOpsFeeds.zip'
        $entry.path     | Should -Be 'templates/registerModusOpsFeeds/action.yml'
        $entry.sha256   | Should -Match '^[0-9A-F]{64}$'

        # The pinned hash is the SHA256 of the laid-down action.yml (Test-MOTemplate verifies against this).
        $actual = (Get-FileHash -LiteralPath (Join-Path $tmp $entry.path) -Algorithm SHA256).Hash
        $entry.sha256 | Should -Be $actual
    }
}
