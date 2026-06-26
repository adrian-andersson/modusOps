BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Read-MOTemplateLock'
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

Describe 'Read-MOTemplateLock' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'returns an empty default structure when the lockfile is missing' {
        $lock = Read-MOTemplateLock -Path (Join-Path $tmp 'nope.lock')
        $lock.lockfileVersion | Should -Be 1
        $lock.templates | Should -BeOfType ([hashtable])
        $lock.templates.Keys.Count | Should -Be 0
    }

    It 'reads templates into a mutable hashtable' {
        $path = Join-Path $tmp '.modusops.lock'
        @{
            lockfileVersion = 1
            source          = 'https://github.com/o/r'
            templates       = @{ registerModusOpsFeeds = @{ version = 'v0.1.0'; sha256 = 'ABC'; path = 'templates/registerModusOpsFeeds.yml' } }
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path

        $lock = Read-MOTemplateLock -Path $path
        $lock.source | Should -Be 'https://github.com/o/r'
        $lock.templates | Should -BeOfType ([hashtable])
        $lock.templates['registerModusOpsFeeds'].sha256 | Should -Be 'ABC'
        # mutable: callers add entries directly
        $lock.templates['another'] = @{ version = 'v0.2.0' }
        $lock.templates.Keys.Count | Should -Be 2
    }
}
