BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Invoke-GitHubRest'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-GitHubRest' {
    BeforeEach {
        Mock Invoke-RestMethod { [pscustomobject]@{ ok = $true } }
    }

    It 'sends the GitHub Accept + api-version headers' {
        Invoke-GitHubRest -Uri 'https://api.github.com/repos/o/r/releases/latest'
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Headers['Accept'] -eq 'application/vnd.github+json' -and
            $Headers['X-GitHub-Api-Version'] -eq '2022-11-28'
        }
    }

    It 'omits Authorization when no token is supplied' {
        Invoke-GitHubRest -Uri 'https://api.github.com/x'
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { -not $Headers.ContainsKey('Authorization') }
    }

    It 'sends a Bearer token when supplied' {
        $token = ConvertTo-SecureString 'ghp_secret' -AsPlainText -Force
        Invoke-GitHubRest -Uri 'https://api.github.com/x' -Token $token
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Headers['Authorization'] -eq 'Bearer ghp_secret' }
    }

    It 'serialises a body to JSON and sets the content type' {
        Invoke-GitHubRest -Uri 'https://api.github.com/x' -Method Post -Body @{ name = 'v1' }
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $ContentType -eq 'application/json' -and ($Body | ConvertFrom-Json).name -eq 'v1'
        }
    }

    It 'returns the deserialised response' {
        (Invoke-GitHubRest -Uri 'https://api.github.com/x').ok | Should -BeTrue
    }
}
