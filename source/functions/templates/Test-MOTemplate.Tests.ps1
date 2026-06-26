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
    $functionName = 'Test-MOTemplate'
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

Describe 'Test-MOTemplate' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null

        # A real vendored file whose hash we pin, plus a second entry we leave missing.
        $tplDir = Join-Path $tmp 'templates'
        New-Item -ItemType Directory -Path $tplDir -Force | Out-Null
        $alphaPath = Join-Path $tplDir 'alpha.yml'
        Set-Content -LiteralPath $alphaPath -Value "steps:`n  - script: echo hi" -NoNewline
        $alphaSha = (Get-FileHash -LiteralPath $alphaPath -Algorithm SHA256).Hash

        $lockPath = Join-Path $tmp '.modusops.lock'
        @{
            lockfileVersion = 1
            source          = 'https://github.com/o/r'
            templates       = @{
                alpha = @{ version = 'v1'; platform = 'azd'; path = 'templates/alpha.yml'; sha256 = $alphaSha }
                gone  = @{ version = 'v1'; platform = 'azd'; path = 'templates/gone.yml';  sha256 = 'ZZZ' }
            }
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $lockPath
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'reports OK when the local file matches the pinned hash' {
        $result = @(Test-MOTemplate -Name alpha -ProjectPath $tmp)
        $result[0].Status | Should -Be 'OK'
    }

    It 'reports Drifted when the local file was edited' {
        Set-Content -LiteralPath (Join-Path $tmp 'templates/alpha.yml') -Value 'tampered' -NoNewline
        $result = @(Test-MOTemplate -Name alpha -ProjectPath $tmp -WarningAction SilentlyContinue)
        $result[0].Status | Should -Be 'Drifted'
        $result[0].Actual | Should -Not -Be $result[0].Expected
    }

    It 'reports Missing when the local file is absent' {
        $result = @(Test-MOTemplate -Name gone -ProjectPath $tmp -WarningAction SilentlyContinue)
        $result[0].Status | Should -Be 'Missing'
        $result[0].Actual | Should -BeNullOrEmpty
    }

    It 'makes no network calls (offline)' {
        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        Mock Invoke-WebRequest { throw 'No real HTTP in tests' }
        Test-MOTemplate -ProjectPath $tmp -WarningAction SilentlyContinue | Out-Null
        Should -Invoke Invoke-RestMethod -Times 0
        Should -Invoke Invoke-WebRequest -Times 0
    }
}
