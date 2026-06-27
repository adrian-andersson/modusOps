BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    $dependencies = @('Read-MOTemplateLock.ps1', 'Write-MOTemplateLock.ps1')
    $dependencies.ForEach{
        if ($sourceMap.ContainsKey($_)) { . $sourceMap[$_] }
        else { Write-Warning "Dependency not found under source: $_" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Set-MOPlatform'
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

Describe 'Set-MOPlatform' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'writes defaults.platform into a new lockfile' {
        Set-MOPlatform -Platform gh -ProjectPath $tmp
        $lock = Get-Content (Join-Path $tmp '.modusops.lock') -Raw | ConvertFrom-Json
        $lock.defaults.platform | Should -Be 'gh'
    }

    It 'round-trips through Read-MOTemplateLock' {
        Set-MOPlatform -Platform azd -ProjectPath $tmp
        $lock = Read-MOTemplateLock -Path (Join-Path $tmp '.modusops.lock')
        $lock.defaults.platform | Should -Be 'azd'
    }

    It 'preserves existing template entries' {
        Write-MOTemplateLock -Lock @{ source = 'https://x/y'; templates = @{ alpha = @{ version = 'v1' } } } -Path (Join-Path $tmp '.modusops.lock')
        Set-MOPlatform -Platform gh -ProjectPath $tmp
        $lock = Read-MOTemplateLock -Path (Join-Path $tmp '.modusops.lock')
        $lock.defaults.platform | Should -Be 'gh'
        $lock.templates['alpha'].version | Should -Be 'v1'
    }

    It 'returns the platform and source' {
        $r = Set-MOPlatform -Platform gh -ProjectPath $tmp
        $r.Platform | Should -Be 'gh'
        $r.Source   | Should -Be 'lockfile'
    }

    It 'honours -WhatIf - writes no lockfile' {
        Set-MOPlatform -Platform gh -ProjectPath $tmp -WhatIf
        (Test-Path (Join-Path $tmp '.modusops.lock')) | Should -BeFalse
    }

    It 'rejects an invalid platform' {
        { Set-MOPlatform -Platform aws -ProjectPath $tmp } | Should -Throw
    }
}
