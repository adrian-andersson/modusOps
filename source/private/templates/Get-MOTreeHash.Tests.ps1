BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Get-MOTreeHash'
    . $fileName

    $testTempBase = Join-Path $currentPath ".pestertmp_$functionName"
    if (Test-Path $testTempBase) { Remove-Item $testTempBase -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $testTempBase -Force | Out-Null

    function New-TreeFixture {
        param($Root, $Files)
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
        foreach ($name in $Files.Keys) {
            $p = Join-Path $Root $name
            $dir = Split-Path -Parent $p
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Set-Content -LiteralPath $p -Value $Files[$name] -NoNewline
        }
    }
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

Describe 'Get-MOTreeHash' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'returns a lowercase 64-char hex digest' {
        New-TreeFixture -Root (Join-Path $tmp 'a') -Files @{ 'one.yml' = 'x' }
        Get-MOTreeHash -Path (Join-Path $tmp 'a') | Should -Match '^[0-9a-f]{64}$'
    }

    It 'is deterministic for identical content (independent of directory)' {
        $files = @{ 'issue.yml' = 'name: x'; '_config.yml' = 'blank_issues_enabled: false' }
        New-TreeFixture -Root (Join-Path $tmp 'a') -Files $files
        New-TreeFixture -Root (Join-Path $tmp 'b') -Files $files
        Get-MOTreeHash -Path (Join-Path $tmp 'a') | Should -Be (Get-MOTreeHash -Path (Join-Path $tmp 'b'))
    }

    It 'changes when a file body changes' {
        New-TreeFixture -Root (Join-Path $tmp 'a') -Files @{ 'one.yml' = 'before' }
        $before = Get-MOTreeHash -Path (Join-Path $tmp 'a')
        Set-Content -LiteralPath (Join-Path $tmp 'a/one.yml') -Value 'after' -NoNewline
        Get-MOTreeHash -Path (Join-Path $tmp 'a') | Should -Not -Be $before
    }

    It 'changes when a file is added' {
        New-TreeFixture -Root (Join-Path $tmp 'a') -Files @{ 'one.yml' = 'x' }
        $before = Get-MOTreeHash -Path (Join-Path $tmp 'a')
        Set-Content -LiteralPath (Join-Path $tmp 'a/two.yml') -Value 'y' -NoNewline
        Get-MOTreeHash -Path (Join-Path $tmp 'a') | Should -Not -Be $before
    }
}
