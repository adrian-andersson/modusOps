BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    # Lockfile helpers are real (pure file I/O); Resolve reads the lock for its default rung.
    $dependencies = @('Read-MOTemplateLock.ps1', 'Write-MOTemplateLock.ps1')
    $dependencies.ForEach{
        if ($sourceMap.ContainsKey($_)) { . $sourceMap[$_] }
        else { Write-Warning "Dependency not found under source: $_" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Resolve-MOPlatform'
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

Describe 'Resolve-MOPlatform' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'returns the explicit -Platform regardless of context' {
        # Even with a conflicting lock default, the explicit argument wins.
        Write-MOTemplateLock -Lock @{ defaults = @{ platform = 'gh' }; templates = @{} } -Path (Join-Path $tmp '.modusops.lock')
        Resolve-MOPlatform -Platform azd -ProjectPath $tmp | Should -Be 'azd'
    }

    It 'uses the lockfile default when no -Platform is given' {
        Write-MOTemplateLock -Lock @{ defaults = @{ platform = 'gh' }; templates = @{} } -Path (Join-Path $tmp '.modusops.lock')
        Resolve-MOPlatform -ProjectPath $tmp | Should -Be 'gh'
    }

    It 'auto-detects gh from a .github directory' {
        New-Item -ItemType Directory -Path (Join-Path $tmp '.github') -Force | Out-Null
        Resolve-MOPlatform -ProjectPath $tmp | Should -Be 'gh'
    }

    It 'auto-detects azd from azure-pipelines.yml' {
        Set-Content -LiteralPath (Join-Path $tmp 'azure-pipelines.yml') -Value 'trigger: none' -NoNewline
        Resolve-MOPlatform -ProjectPath $tmp | Should -Be 'azd'
    }

    It 'throws a directive error when it cannot be determined' {
        { Resolve-MOPlatform -ProjectPath $tmp } | Should -Throw '*Set-MOPlatform*'
    }

    It 'throws when both platform signals are present (ambiguous)' {
        New-Item -ItemType Directory -Path (Join-Path $tmp '.github') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $tmp 'azure-pipelines.yml') -Value 'trigger: none' -NoNewline
        { Resolve-MOPlatform -ProjectPath $tmp } | Should -Throw
    }
}
