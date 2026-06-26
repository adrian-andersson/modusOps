BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    $dependencies = @(
        'Invoke-GitHubRest.ps1'
        'Save-GitHubReleaseAsset.ps1'
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
    $functionName = 'Update-MOTemplate'
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

Describe 'Update-MOTemplate' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null

        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        Mock Invoke-WebRequest { throw 'No real HTTP in tests' }

        # Seed a vendored file at v0.1.0 and pin its real hash.
        $script:originalContent = "steps:`n  - script: echo original"
        $tplDir = Join-Path $tmp 'templates'
        New-Item -ItemType Directory -Path $tplDir -Force | Out-Null
        $alphaPath = Join-Path $tplDir 'alpha.yml'
        Set-Content -LiteralPath $alphaPath -Value $script:originalContent -NoNewline
        $alphaSha = (Get-FileHash -LiteralPath $alphaPath -Algorithm SHA256).Hash

        $lockPath = Join-Path $tmp '.modusops.lock'
        @{
            lockfileVersion = 1
            source          = 'https://github.com/o/r'
            templates       = @{ alpha = @{ version = 'v0.1.0'; platform = 'azd'; asset = 'azd.alpha.yml'; path = 'templates/alpha.yml'; sha256 = $alphaSha; url = 'https://example/old.yml' } }
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $lockPath

        # Target release v0.2.0.
        Mock Get-MOTemplateRelease {
            [pscustomobject]@{ tag_name = 'v0.2.0'; assets = @(
                [pscustomobject]@{ name = 'azd.alpha.yml'; browser_download_url = 'https://example/v0.2.0/azd.alpha.yml' }
            )}
        }
        Mock Get-MOTemplateManifest {
            @{ templates = @{ alpha = @{ platforms = @('azd'); assets = @{ azd = 'azd.alpha.yml' } } } } | ConvertTo-Json -Depth 6 | ConvertFrom-Json
        }
        # Default: the new release serves identical bytes (unchanged path).
        Mock Save-GitHubReleaseAsset { Set-Content -LiteralPath $Path -Value $script:originalContent -NoNewline }
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'reports Unchanged and re-pins the version when bytes are identical' {
        $result = @(Update-MOTemplate -ProjectPath $tmp)
        $result[0].Status | Should -Be 'Unchanged'
        $result[0].From | Should -Be 'v0.1.0'
        $result[0].To | Should -Be 'v0.2.0'
        $lock = Get-Content (Join-Path $tmp '.modusops.lock') -Raw | ConvertFrom-Json
        $lock.templates.alpha.version | Should -Be 'v0.2.0'
    }

    It 'overwrites the file and updates the hash when bytes changed' {
        Mock Save-GitHubReleaseAsset { Set-Content -LiteralPath $Path -Value "steps:`n  - script: echo NEW" -NoNewline }
        $result = @(Update-MOTemplate -ProjectPath $tmp)
        $result[0].Status | Should -Be 'Changed'

        $alphaPath = Join-Path $tmp 'templates/alpha.yml'
        (Get-Content $alphaPath -Raw) | Should -Match 'echo NEW'
        $newSha = (Get-FileHash -LiteralPath $alphaPath -Algorithm SHA256).Hash
        $lock = Get-Content (Join-Path $tmp '.modusops.lock') -Raw | ConvertFrom-Json
        $lock.templates.alpha.sha256 | Should -Be $newSha
        $lock.templates.alpha.version | Should -Be 'v0.2.0'
    }

    It 'throws when no installed template matches -Name' {
        { Update-MOTemplate -Name ghost -ProjectPath $tmp } | Should -Throw '*No installed template matches*'
    }

    It 'honours -WhatIf - file and lockfile version are untouched' {
        Update-MOTemplate -ProjectPath $tmp -WhatIf
        Should -Invoke Save-GitHubReleaseAsset -Times 0
        $lock = Get-Content (Join-Path $tmp '.modusops.lock') -Raw | ConvertFrom-Json
        $lock.templates.alpha.version | Should -Be 'v0.1.0'
    }
}
