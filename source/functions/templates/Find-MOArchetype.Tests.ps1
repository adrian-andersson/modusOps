BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    $dependencies = @(
        'Invoke-GitHubRest.ps1'
        'Save-GitHubReleaseAsset.ps1'
        'Resolve-MOArchetype.ps1'
        'Resolve-MOPlatform.ps1'
        'Read-MOTemplateLock.ps1'
        'Write-MOTemplateLock.ps1'
        'Get-MOTemplateRelease.ps1'
        'Get-MOTemplateManifest.ps1'
    )
    $dependencies.ForEach{
        if ($sourceMap.ContainsKey($_)) { . $sourceMap[$_] }
        else { Write-Warning "Dependency not found under source: $_" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Find-MOArchetype'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Find-MOArchetype' {
    BeforeEach {
        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        Mock Get-MOTemplateRelease { [pscustomobject]@{ tag_name = 'v1'; assets = @() } }
        Mock Get-MOTemplateManifest {
            @{
                templates = @{
                    prValidation        = @{ category = 'repoScaffold'; kind = @{ gh = 'workflow' };   platforms = @('gh') }
                    pullRequestTemplate = @{ category = 'repoScaffold'; kind = @{ gh = 'prTemplate' }; platforms = @('gh') }
                }
                sets = @{
                    templateLibrary = @{ type = 'archetype'; platforms = @('gh'); description = 'lib'; steps = @(
                        @{ type = 'file'; template = 'prValidation' }
                        @{ type = 'file'; template = 'pullRequestTemplate' }
                    ) }
                    workflowSet = @{ type = 'selector'; platforms = @('gh'); description = 'wf'; select = @{ category = 'repoScaffold'; kind = 'workflow' } }
                }
            } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }
    }

    It 'lists the sets with type and resolved member counts' {
        $rows = @(Find-MOArchetype -Platform gh)
        $rows.Count | Should -Be 2
        ($rows | Where-Object Name -eq 'templateLibrary').Type    | Should -Be 'archetype'
        ($rows | Where-Object Name -eq 'templateLibrary').Members | Should -Be 2
        # selector resolves to the one workflow template
        ($rows | Where-Object Name -eq 'workflowSet').Type    | Should -Be 'selector'
        ($rows | Where-Object Name -eq 'workflowSet').Members | Should -Be 1
    }

    It 'filters by name' {
        $rows = @(Find-MOArchetype -Name 'workflow*' -Platform gh)
        $rows.Count | Should -Be 1
        $rows[0].Name | Should -Be 'workflowSet'
    }
}
