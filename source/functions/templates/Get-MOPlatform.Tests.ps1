BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    # Real lockfile helpers + the resolver seam it falls back to for detection.
    $dependencies = @('Read-MOTemplateLock.ps1', 'Write-MOTemplateLock.ps1', 'Resolve-MOPlatform.ps1')
    $dependencies.ForEach{
        if ($sourceMap.ContainsKey($_)) { . $sourceMap[$_] }
        else { Write-Warning "Dependency not found under source: $_" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Get-MOPlatform'
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

Describe 'Get-MOPlatform' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'reports the lockfile default with Source = lockfile' {
        Write-MOTemplateLock -Lock @{ defaults = @{ platform = 'gh' }; templates = @{} } -Path (Join-Path $tmp '.modusops.lock')
        $r = Get-MOPlatform -ProjectPath $tmp
        $r.Platform | Should -Be 'gh'
        $r.Source   | Should -Be 'lockfile'
    }

    It 'reports an auto-detected platform with Source = detected' {
        New-Item -ItemType Directory -Path (Join-Path $tmp '.github') -Force | Out-Null
        $r = Get-MOPlatform -ProjectPath $tmp
        $r.Platform | Should -Be 'gh'
        $r.Source   | Should -Be 'detected'
    }

    It 'reports unset (no throw) when nothing can be resolved' {
        $r = Get-MOPlatform -ProjectPath $tmp
        $r.Platform | Should -BeNullOrEmpty
        $r.Source   | Should -Be 'unset'
    }
}
