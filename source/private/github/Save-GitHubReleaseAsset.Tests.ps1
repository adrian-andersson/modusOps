BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Save-GitHubReleaseAsset'
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

Describe 'Save-GitHubReleaseAsset' {
    BeforeEach {
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        Mock Invoke-WebRequest { }
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'downloads to the requested path with octet-stream Accept' {
        $dest = Join-Path $tmp 'asset.yml'
        Save-GitHubReleaseAsset -Uri 'https://github.com/o/r/releases/download/v1/azd.x.yml' -Path $dest
        Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter {
            $OutFile -eq $dest -and $Headers['Accept'] -eq 'application/octet-stream'
        }
    }

    It 'omits Authorization when no token is supplied' {
        Save-GitHubReleaseAsset -Uri 'https://example/x' -Path (Join-Path $tmp 'a.yml')
        Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter { -not $Headers.ContainsKey('Authorization') }
    }

    It 'sends a Bearer token when supplied' {
        $token = ConvertTo-SecureString 'ghp_secret' -AsPlainText -Force
        Save-GitHubReleaseAsset -Uri 'https://example/x' -Path (Join-Path $tmp 'b.yml') -Token $token
        Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter { $Headers['Authorization'] -eq 'Bearer ghp_secret' }
    }
}
