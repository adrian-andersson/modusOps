BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    foreach($dep in @('Read-MOTemplateLock.ps1')){
        if ($sourceMap.ContainsKey($dep)) { . $sourceMap[$dep] }
        else { Write-Warning "Dependency not found under source: $dep" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Write-MOTemplateLock'
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

Describe 'Write-MOTemplateLock' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'round-trips through Read-MOTemplateLock' {
        $path = Join-Path $tmp '.modusops.lock'
        $lock = @{
            lockfileVersion = 1
            source          = 'https://github.com/o/r'
            templates       = @{ alpha = @{ version = 'v1'; sha256 = 'AAA' } }
        }
        Write-MOTemplateLock -Lock $lock -Path $path
        (Test-Path $path) | Should -BeTrue

        $back = Read-MOTemplateLock -Path $path
        $back.source | Should -Be 'https://github.com/o/r'
        $back.templates['alpha'].sha256 | Should -Be 'AAA'
    }

    It 'writes template entries in sorted name order for stable diffs' {
        $path = Join-Path $tmp '.modusops.lock'
        $lock = @{
            lockfileVersion = 1
            source          = 'https://github.com/o/r'
            templates       = @{ zebra = @{ version = 'v1' }; alpha = @{ version = 'v1' }; mango = @{ version = 'v1' } }
        }
        Write-MOTemplateLock -Lock $lock -Path $path

        $text = Get-Content -LiteralPath $path -Raw
        $idxAlpha = $text.IndexOf('alpha')
        $idxMango = $text.IndexOf('mango')
        $idxZebra = $text.IndexOf('zebra')
        $idxAlpha | Should -BeLessThan $idxMango
        $idxMango | Should -BeLessThan $idxZebra
    }
}
