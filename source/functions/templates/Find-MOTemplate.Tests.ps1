BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    foreach($dep in @('Invoke-GitHubRest.ps1','Save-GitHubReleaseAsset.ps1','Get-MOTemplateRelease.ps1','Get-MOTemplateManifest.ps1')){
        if ($sourceMap.ContainsKey($dep)) { . $sourceMap[$dep] }
        else { Write-Warning "Dependency not found under source: $dep" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Find-MOTemplate'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Find-MOTemplate' {
    BeforeEach {
        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        Mock Get-MOTemplateRelease { [pscustomobject]@{ tag_name = 'v0.1.0'; assets = @() } }
        Mock Get-MOTemplateManifest {
            @{
                templates = @{
                    registerModusOpsFeeds = @{ description = 'feeds'; platforms = @('azd'); assets = @{ azd = 'azd.registerModusOpsFeeds.yml' } }
                    sendTeamsChannelMessage = @{ description = 'teams'; platforms = @('azd'); assets = @{ azd = 'azd.sendTeamsChannelMessage.yml' } }
                    futureGhThing = @{ description = 'gh only'; platforms = @('gh'); assets = @{ gh = 'gh.futureGhThing.yml' } }
                }
            } | ConvertTo-Json -Depth 6 | ConvertFrom-Json
        }
    }

    It 'lists all templates in the release with the release version' {
        $result = @(Find-MOTemplate)
        $result.Count | Should -Be 3
        ($result | Where-Object Name -eq 'registerModusOpsFeeds').Version | Should -Be 'v0.1.0'
    }

    It 'filters by name wildcard' {
        $result = @(Find-MOTemplate -Name 'send*')
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'sendTeamsChannelMessage'
    }

    It 'filters by platform' {
        $result = @(Find-MOTemplate -Platform azd)
        $result.Name | Should -Not -Contain 'futureGhThing'
        $result.Count | Should -Be 2
    }

    It 'passes -Version through to the release resolver' {
        Find-MOTemplate -Version v0.1.0 | Out-Null
        Should -Invoke Get-MOTemplateRelease -Times 1 -ParameterFilter { $Version -eq 'v0.1.0' }
    }
}
