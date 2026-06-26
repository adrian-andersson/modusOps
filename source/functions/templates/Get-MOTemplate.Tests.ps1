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
    $functionName = 'Get-MOTemplate'
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

Describe 'Get-MOTemplate' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null

        $lockPath = Join-Path $tmp '.modusops.lock'
        @{
            lockfileVersion = 1
            source          = 'https://github.com/o/r'
            templates       = @{
                bravo = @{ version = 'v0.2.0'; platform = 'azd'; path = 'templates/bravo.yml'; sha256 = 'BBB' }
                alpha = @{ version = 'v0.1.0'; platform = 'azd'; path = 'templates/alpha.yml'; sha256 = 'AAA' }
            }
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $lockPath
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'lists all installed templates sorted by name' {
        $result = @(Get-MOTemplate -ProjectPath $tmp)
        $result.Count | Should -Be 2
        $result[0].Name | Should -Be 'alpha'
        $result[1].Name | Should -Be 'bravo'
        $result[0].Source | Should -Be 'https://github.com/o/r'
    }

    It 'filters by name' {
        $result = @(Get-MOTemplate -Name bravo -ProjectPath $tmp)
        $result.Count | Should -Be 1
        $result[0].Version | Should -Be 'v0.2.0'
    }

    It 'returns nothing when the lockfile is absent' {
        $empty = Join-Path $tmp 'emptyproj'
        New-Item -ItemType Directory -Path $empty | Out-Null
        @(Get-MOTemplate -ProjectPath $empty).Count | Should -Be 0
    }
}
