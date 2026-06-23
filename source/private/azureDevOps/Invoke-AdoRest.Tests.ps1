BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    # Invoke-AdoRest's only dependency is Invoke-RestMethod, which we mock per-test.
    $dependencies = @()
    $dependencies.ForEach{
        if ($sourceMap.ContainsKey($_)) { . $sourceMap[$_] }
        else { Write-Warning "Dependency not found under source: $_" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Invoke-AdoRest'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-AdoRest' {
    BeforeEach {
        # The single seam to the network. Always mocked — a real call never happens in tests.
        Mock Invoke-RestMethod { 'mock-response' }
    }

    It 'returns whatever Invoke-RestMethod returns' {
        Invoke-AdoRest -Uri 'https://x/_apis/y' -Headers @{ Authorization = 'Basic z' } | Should -Be 'mock-response'
    }

    It 'defaults to the GET method' {
        Invoke-AdoRest -Uri 'https://x' -Headers @{}
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'Get' }
    }

    It 'passes Uri, Method and Headers straight through' {
        $h = @{ Authorization = 'Basic z' }
        Invoke-AdoRest -Uri 'https://x/thing' -Method 'Post' -Headers $h -Body @{ a = 1 }
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Uri -eq 'https://x/thing' -and $Method -eq 'Post' -and $Headers.Authorization -eq 'Basic z'
        }
    }

    It 'sends a JSON content type and stops on error' {
        Invoke-AdoRest -Uri 'https://x' -Headers @{}
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $ContentType -eq 'application/json' -and $ErrorAction -eq 'Stop'
        }
    }

    It 'serialises the body to JSON when one is supplied' {
        # Note: PowerShell variables are case-insensitive, so the expected value must NOT be named
        # $body — that would collide with the mock's captured $Body (already a JSON string).
        $payload  = @{ name = 'demo'; nested = @{ a = 1 } }
        $expected = $payload | ConvertTo-Json -Depth 20
        Invoke-AdoRest -Uri 'https://x' -Method 'Post' -Headers @{} -Body $payload
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Body -eq $expected }
    }

    It 'omits the body entirely when none is supplied' {
        Invoke-AdoRest -Uri 'https://x' -Headers @{}
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $null -eq $Body }
    }
}
