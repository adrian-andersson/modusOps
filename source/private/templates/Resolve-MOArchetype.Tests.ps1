BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Resolve-MOArchetype'
    . $fileName

    # A manifest in the same shape Get-MOTemplateManifest returns (PSCustomObject from JSON).
    $script:manifest = @{
        templates = @{
            prValidation          = @{ category = 'repoScaffold'; kind = @{ gh = 'workflow' };     platforms = @('gh') }
            release               = @{ category = 'repoScaffold'; kind = @{ gh = 'workflow' };     platforms = @('gh') }
            pullRequestTemplate   = @{ category = 'repoScaffold'; kind = @{ gh = 'prTemplate' };   platforms = @('gh') }
            registerModusOpsFeeds = @{ category = 'pipeline';     kind = @{ azd = 'stepTemplate'; gh = 'compositeAction' }; platforms = @('azd','gh') }
        }
        sets = @{
            templateLibrary = @{ type = 'archetype'; platforms = @('gh'); steps = @(
                @{ type = 'file'; template = 'prValidation' }
                @{ type = 'file'; template = 'pullRequestTemplate' }
            ) }
            workflowSet   = @{ type = 'selector'; platforms = @('gh'); select = @{ category = 'repoScaffold'; kind = 'workflow' } }
            withExclude   = @{ type = 'selector'; platforms = @('gh'); select = @{ category = 'repoScaffold'; kind = 'workflow' }; exclude = @('release') }
            withProvision = @{ type = 'archetype'; platforms = @('gh'); steps = @(
                @{ type = 'file'; template = 'prValidation' }
                @{ type = 'provision'; id = 'buildValidation'; cmdlet = 'Add-MOAzureDevOpsModusBuildValidation'; with = @{ RepositoryName = '{repo}' } }
            ) }
            badRef          = @{ type = 'archetype'; platforms = @('gh'); steps = @(@{ type = 'file'; template = 'ghost' }) }
            badStepType     = @{ type = 'archetype'; platforms = @('gh'); steps = @(@{ type = 'mystery'; template = 'prValidation' }) }
            noCmdlet        = @{ type = 'archetype'; platforms = @('gh'); steps = @(@{ type = 'provision' }) }
            azdOnly         = @{ type = 'archetype'; platforms = @('azd'); steps = @(@{ type = 'file'; template = 'registerModusOpsFeeds' }) }
        }
    } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Resolve-MOArchetype' {
    It 'expands a curated archetype into its ordered file members' {
        $m = @(Resolve-MOArchetype -Manifest $manifest -Archetype templateLibrary -Platform gh)
        $m.Count | Should -Be 2
        $m[0].Template | Should -Be 'prValidation'
        $m[1].Template | Should -Be 'pullRequestTemplate'
    }

    It 'expands a selector to all matching templates (sorted)' {
        $m = @(Resolve-MOArchetype -Manifest $manifest -Archetype workflowSet -Platform gh)
        @($m.Template) | Should -Be @('prValidation','release')
    }

    It 'honours selector exclude' {
        $m = @(Resolve-MOArchetype -Manifest $manifest -Archetype withExclude -Platform gh)
        @($m.Template) | Should -Be @('prValidation')
    }

    It 'narrows by -Include kind' {
        $m = @(Resolve-MOArchetype -Manifest $manifest -Archetype templateLibrary -Platform gh -Include workflow)
        @($m.Template) | Should -Be @('prValidation')
    }

    It 'includes provision steps as provision members (with cmdlet + with-map)' {
        $m = @(Resolve-MOArchetype -Manifest $manifest -Archetype withProvision -Platform gh)
        $m.Count | Should -Be 2
        $m[0].StepType | Should -Be 'file'
        $m[0].Template | Should -Be 'prValidation'
        $m[1].StepType | Should -Be 'provision'
        $m[1].Name     | Should -Be 'buildValidation'
        $m[1].Cmdlet   | Should -Be 'Add-MOAzureDevOpsModusBuildValidation'
        $m[1].With.RepositoryName | Should -Be '{repo}'
    }

    It 'drops provision steps when -Include narrows by kind' {
        $m = @(Resolve-MOArchetype -Manifest $manifest -Archetype withProvision -Platform gh -Include workflow)
        @($m.Template) | Should -Be @('prValidation')
    }

    It 'throws on an unknown step type' {
        { Resolve-MOArchetype -Manifest $manifest -Archetype badStepType -Platform gh } | Should -Throw '*unknown step type*'
    }

    It 'throws on a provision step with no cmdlet' {
        { Resolve-MOArchetype -Manifest $manifest -Archetype noCmdlet -Platform gh } | Should -Throw '*no cmdlet*'
    }

    It 'throws on a curated step referencing an unknown template' {
        { Resolve-MOArchetype -Manifest $manifest -Archetype badRef -Platform gh } | Should -Throw '*unknown template*'
    }

    It 'throws when the set does not support the platform' {
        { Resolve-MOArchetype -Manifest $manifest -Archetype azdOnly -Platform gh } | Should -Throw '*does not support platform*'
    }

    It 'throws when the set is not in the manifest' {
        { Resolve-MOArchetype -Manifest $manifest -Archetype ghostSet -Platform gh } | Should -Throw '*not in the manifest*'
    }
}
