BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    # Push-MO...Content does not use Get-AdoResource - it talks to the seam directly.
    $dependencies = @(
        'Get-AuthHeader.ps1'
        'Invoke-AdoRest.ps1'
    )
    $dependencies.ForEach{
        if ($sourceMap.ContainsKey($_)) { . $sourceMap[$_] }
        else { Write-Warning "Dependency not found under source: $_" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Push-MOAzureDevOpsModusContent'
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

Describe 'Push-MOAzureDevOpsModusContent' {
    BeforeAll {
        $cred = [pscredential]::new('pat', (ConvertTo-SecureString 'secret-pat' -AsPlainText -Force))
    }

    BeforeEach {
        # A real on-disk source folder (simulates a staged operations-repo tree). Real file I/O on a
        # repo-local temp dir - no need to mock Get-ChildItem / Resolve-Path / Get-Content.
        $tmp = Join-Path $testTempBase ([guid]::NewGuid().ToString('N'))
        $sourceDir = Join-Path $tmp 'content'
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $sourceDir 'examplePipeline.yml') -Value 'a: 1'
        New-Item -ItemType Directory -Path (Join-Path $sourceDir 'templates') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $sourceDir 'templates/registerModusOpsFeeds.yml') -Value 'b: 2'

        Mock Invoke-RestMethod { throw 'No real HTTP in tests' }
        # Repo lookup (GET) + best-effort default-branch patch fall through to this.
        Mock Invoke-AdoRest { [pscustomobject]@{ id = 'repo-1' } }
        # Refs (GET) - empty repo, so content is safe to push.
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/refs\?' } -MockWith {
            [pscustomobject]@{ count = 0; value = @() }
        }
        # The push (POST).
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/pushes\?' -and $Method -eq 'Post' } -MockWith {
            [pscustomobject]@{ commits = @([pscustomobject]@{ commitId = 'abc' }) }
        }
    }
    AfterEach {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'pushes staged content as an initial commit to an empty repo' {
        $result = Push-MOAzureDevOpsModusContent -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOps -SourcePath $sourceDir
        Should -Invoke Invoke-AdoRest -Times 1 -ParameterFilter { $Uri -match '/pushes\?' -and $Method -eq 'Post' }
        $result.Files  | Should -Be 2
        $result.Branch | Should -Be 'main'
    }

    It 'skips a repository that already has content (never clobbers)' {
        Mock Invoke-AdoRest -ParameterFilter { $Uri -match '/refs\?' } -MockWith {
            [pscustomobject]@{ count = 1; value = @([pscustomobject]@{ name = 'refs/heads/main' }) }
        }
        Push-MOAzureDevOpsModusContent -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOps -SourcePath $sourceDir
        Should -Invoke Invoke-AdoRest -Times 0 -ParameterFilter { $Method -eq 'Post' }
    }

    It 'applies -Exclude patterns' {
        $result = Push-MOAzureDevOpsModusContent -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOps -SourcePath $sourceDir -Exclude '*registerModusOpsFeeds.yml'
        $result.Files | Should -Be 1
    }

    It 'throws when the source path does not exist' {
        { Push-MOAzureDevOpsModusContent -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOps -SourcePath (Join-Path $tmp 'no-such-folder') } |
            Should -Throw '*Source path not found*'
    }

    It 'throws when there are no files to push' {
        $empty = Join-Path $tmp 'empty'
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        { Push-MOAzureDevOpsModusContent -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOps -SourcePath $empty } |
            Should -Throw '*No files found*'
    }

    It 'requires -SourcePath (no bundled-content default)' {
        (Get-Command Push-MOAzureDevOpsModusContent).Parameters['SourcePath'].Attributes.Mandatory | Should -Contain $true
    }

    It 'honours -WhatIf - performs no push' {
        Push-MOAzureDevOpsModusContent -OrganizationUri 'https://dev.azure.com/contoso' -Credential $cred -RepositoryName modusOps -SourcePath $sourceDir -WhatIf
        Should -Invoke Invoke-AdoRest -Times 0 -ParameterFilter { $Method -in 'Post', 'Patch' }
    }
}
