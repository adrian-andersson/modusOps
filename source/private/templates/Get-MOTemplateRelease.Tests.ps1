BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    foreach($dep in @('Invoke-GitHubRest.ps1')){
        if ($sourceMap.ContainsKey($dep)) { . $sourceMap[$dep] }
        else { Write-Warning "Dependency not found under source: $dep" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Get-MOTemplateRelease'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Get-MOTemplateRelease' {
    BeforeEach {
        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        Mock Invoke-GitHubRest { [pscustomobject]@{ tag_name = 'v0.1.0'; assets = @() } }
    }

    It 'queries the latest release when no version is given' {
        Get-MOTemplateRelease -Source 'https://github.com/adrian-andersson/modusops-templates'
        Should -Invoke Invoke-GitHubRest -Times 1 -ParameterFilter {
            $Uri -eq 'https://api.github.com/repos/adrian-andersson/modusops-templates/releases/latest'
        }
    }

    It 'queries a specific tag when -Version is given' {
        Get-MOTemplateRelease -Source 'https://github.com/o/r' -Version 'v0.1.0'
        Should -Invoke Invoke-GitHubRest -Times 1 -ParameterFilter {
            $Uri -eq 'https://api.github.com/repos/o/r/releases/tags/v0.1.0'
        }
    }

    It 'tolerates a trailing .git on the source URL' {
        Get-MOTemplateRelease -Source 'https://github.com/o/r.git'
        Should -Invoke Invoke-GitHubRest -Times 1 -ParameterFilter {
            $Uri -eq 'https://api.github.com/repos/o/r/releases/latest'
        }
    }

    It 'throws on an unrecognisable source URL' {
        { Get-MOTemplateRelease -Source 'https://example.com/not-github' } | Should -Throw '*not a recognisable GitHub*'
    }

    It 'returns the release object' {
        (Get-MOTemplateRelease -Source 'https://github.com/o/r').tag_name | Should -Be 'v0.1.0'
    }
}
