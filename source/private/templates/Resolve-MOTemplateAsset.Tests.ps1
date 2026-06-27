BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    # The download seam is dot-sourced then mocked; no network in tests. Get-MOTreeHash is real (pure hash).
    $dependencies = @(
        'Save-GitHubReleaseAsset.ps1'
        'Get-MOTreeHash.ps1'
    )
    $dependencies.ForEach{
        if ($sourceMap.ContainsKey($_)) { . $sourceMap[$_] }
        else { Write-Warning "Dependency not found under source: $_" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Resolve-MOTemplateAsset'
    . $fileName

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

Describe 'Resolve-MOTemplateAsset' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null

        Mock Invoke-WebRequest { throw 'No real HTTP in tests' }

        $script:tmp = $tmp
        $script:ymlContent    = "steps:`n  - script: echo hi"
        $script:actionContent = "name: 'x'`nruns:`n  using: composite"
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Context 'single-file (.yml) asset' {
        BeforeEach {
            Mock Save-GitHubReleaseAsset { Set-Content -LiteralPath $Path -Value $script:ymlContent -NoNewline }
        }

        It 'returns a non-archive descriptor with the file as the entry' {
            $r = Resolve-MOTemplateAsset -Uri 'https://example/azd.foo.yml' -AssetName 'azd.foo.yml'
            try {
                $r.IsArchive | Should -BeFalse
                $r.IntegrityMode | Should -Be 'file'
                $r.EntryName | Should -Be 'azd.foo.yml'
                (Test-Path -LiteralPath $r.EntryFile) | Should -BeTrue
                (Get-Content -LiteralPath $r.EntryFile -Raw) | Should -Be $script:ymlContent
            } finally {
                if (Test-Path $r.StageRoot) { Remove-Item $r.StageRoot -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }

        It 'hashes the downloaded file' {
            $r = Resolve-MOTemplateAsset -Uri 'https://example/azd.foo.yml' -AssetName 'azd.foo.yml'
            try {
                $expected = (Get-FileHash -LiteralPath $r.EntryFile -Algorithm SHA256).Hash
                $r.Sha256 | Should -Be $expected
                $r.Sha256 | Should -Match '^[0-9A-F]{64}$'
            } finally {
                if (Test-Path $r.StageRoot) { Remove-Item $r.StageRoot -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    Context 'archive (.zip) asset' {
        BeforeEach {
            # Mock the download by building a real zip containing action.yml at the requested path.
            Mock Save-GitHubReleaseAsset {
                $src = Join-Path $script:tmp ('src' + [guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $src -Force | Out-Null
                Set-Content -LiteralPath (Join-Path $src 'action.yml') -Value $script:actionContent -NoNewline
                Compress-Archive -Path (Join-Path $src '*') -DestinationPath $Path -Force
            }
        }

        It 'expands the zip and surfaces action.yml as the entry' {
            $r = Resolve-MOTemplateAsset -Uri 'https://example/gh.foo.zip' -AssetName 'gh.foo.zip'
            try {
                $r.IsArchive | Should -BeTrue
                $r.IntegrityMode | Should -Be 'file'
                $r.EntryName | Should -Be 'action.yml'
                (Test-Path -LiteralPath $r.EntryFile) | Should -BeTrue
                (Get-Content -LiteralPath $r.EntryFile -Raw) | Should -Be $script:actionContent
                # ContentPath is the expanded directory holding action.yml
                (Test-Path -LiteralPath (Join-Path $r.ContentPath 'action.yml')) | Should -BeTrue
            } finally {
                if (Test-Path $r.StageRoot) { Remove-Item $r.StageRoot -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }

        It 'hashes the inner action.yml' {
            $r = Resolve-MOTemplateAsset -Uri 'https://example/gh.foo.zip' -AssetName 'gh.foo.zip'
            try {
                $expected = (Get-FileHash -LiteralPath $r.EntryFile -Algorithm SHA256).Hash
                $r.Sha256 | Should -Be $expected
            } finally {
                if (Test-Path $r.StageRoot) { Remove-Item $r.StageRoot -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    Context 'archive without action.yml (directory set)' {
        BeforeEach {
            # A multi-file dir set (e.g. an issue-template set) - no action.yml at root.
            Mock Save-GitHubReleaseAsset {
                $src = Join-Path $script:tmp ('src' + [guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $src -Force | Out-Null
                Set-Content -LiteralPath (Join-Path $src 'issue.yml')   -Value 'name: x' -NoNewline
                Set-Content -LiteralPath (Join-Path $src '_config.yml') -Value 'blank_issues_enabled: false' -NoNewline
                Compress-Archive -Path (Join-Path $src '*') -DestinationPath $Path -Force
            }
        }

        It 'treats it as a tree-hashed directory set instead of throwing' {
            $r = Resolve-MOTemplateAsset -Uri 'https://example/gh.set.zip' -AssetName 'gh.set.zip'
            try {
                $r.IsArchive | Should -BeTrue
                $r.IntegrityMode | Should -Be 'tree'
                $r.EntryFile | Should -BeNullOrEmpty
                (Test-Path -LiteralPath (Join-Path $r.ContentPath 'issue.yml')) | Should -BeTrue
                (Test-Path -LiteralPath (Join-Path $r.ContentPath '_config.yml')) | Should -BeTrue
                # Sha256 is the canonical tree hash (lowercase hex), matching a fresh recompute.
                $r.Sha256 | Should -Be (Get-MOTreeHash -Path $r.ContentPath)
                $r.Sha256 | Should -Match '^[0-9a-f]{64}$'
            } finally {
                if (Test-Path $r.StageRoot) { Remove-Item $r.StageRoot -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    }
}
