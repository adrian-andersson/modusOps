BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    foreach($dep in @('Save-GitHubReleaseAsset.ps1')){
        if ($sourceMap.ContainsKey($dep)) { . $sourceMap[$dep] }
        else { Write-Warning "Dependency not found under source: $dep" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Get-MOTemplateManifest'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Get-MOTemplateManifest' {
    BeforeAll {
        $manifestJson = @{
            manifestVersion = 1
            library         = 'modusops-templates'
            templates       = @{ registerModusOpsFeeds = @{ platforms = @('azd'); assets = @{ azd = 'azd.registerModusOpsFeeds.yml' } } }
        } | ConvertTo-Json -Depth 6
    }

    BeforeEach {
        Mock Invoke-WebRequest { throw 'No real HTTP in tests' }
        # The seam writes the manifest content to wherever it was asked to save it.
        Mock Save-GitHubReleaseAsset { Set-Content -LiteralPath $Path -Value $manifestJson -NoNewline }
    }

    It 'downloads the manifest.json asset and parses it' {
        $release = [pscustomobject]@{ tag_name = 'v0.1.0'; assets = @(
            [pscustomobject]@{ name = 'manifest.json'; browser_download_url = 'https://example/manifest.json' }
            [pscustomobject]@{ name = 'azd.registerModusOpsFeeds.yml'; browser_download_url = 'https://example/x.yml' }
        )}
        $manifest = Get-MOTemplateManifest -Release $release
        $manifest.library | Should -Be 'modusops-templates'
        $manifest.templates.registerModusOpsFeeds.assets.azd | Should -Be 'azd.registerModusOpsFeeds.yml'
        Should -Invoke Save-GitHubReleaseAsset -Times 1 -ParameterFilter { $Uri -eq 'https://example/manifest.json' }
    }

    It 'throws when the release has no manifest.json asset' {
        $release = [pscustomobject]@{ tag_name = 'v0.1.0'; assets = @([pscustomobject]@{ name = 'azd.x.yml' }) }
        { Get-MOTemplateManifest -Release $release } | Should -Throw '*no manifest.json*'
    }
}
