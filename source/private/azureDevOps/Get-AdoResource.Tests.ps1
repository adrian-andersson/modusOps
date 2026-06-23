BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    # Get-AdoResource calls Invoke-AdoRest. It must exist in scope so Pester can mock it.
    $dependencies = @(
        'Invoke-AdoRest.ps1'
    )
    $dependencies.ForEach{
        if ($sourceMap.ContainsKey($_)) { . $sourceMap[$_] }
        else { Write-Warning "Dependency not found under source: $_" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Get-AdoResource'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Get-AdoResource' {
    BeforeEach {
        # Backstop: if any path slips past the seam, fail loudly rather than hit the network.
        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
    }

    It 'returns the resource when the call succeeds' {
        Mock Invoke-AdoRest { [pscustomobject]@{ id = 'abc'; name = 'thing' } }
        (Get-AdoResource -Uri 'https://x/thing' -Headers @{}).id | Should -Be 'abc'
    }

    It 'requests with the GET method' {
        Mock Invoke-AdoRest { [pscustomobject]@{ id = 'abc' } }
        Get-AdoResource -Uri 'https://x/thing' -Headers @{}
        Should -Invoke Invoke-AdoRest -Times 1 -ParameterFilter { $Method -eq 'Get' }
    }

    It 'returns $null when the resource is not found (404)' {
        # Simulate Invoke-RestMethod's real PS7 failure shape for a 404.
        $resp = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
        Mock Invoke-AdoRest { throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Not Found', $resp) }
        Get-AdoResource -Uri 'https://x/missing' -Headers @{} | Should -BeNullOrEmpty
    }

    It 're-throws errors other than 404' {
        $resp = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::InternalServerError)
        Mock Invoke-AdoRest { throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Server Error', $resp) }
        { Get-AdoResource -Uri 'https://x/boom' -Headers @{} } | Should -Throw
    }
}
