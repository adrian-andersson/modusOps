BeforeAll {

    $currentPath = $(Get-Location).path
    $sourcePath  = Join-Path -Path $currentPath -ChildPath 'source'

    # Map every source file by name so dependencies resolve regardless of subfolder. List order is load order.
    $sourceMap = @{}
    Get-ChildItem -Path $sourcePath -Recurse -Filter '*.ps1' -File | ForEach-Object {
        if (-not $sourceMap.ContainsKey($_.Name)) { $sourceMap[$_.Name] = $_.FullName }
    }

    # Get-AuthHeader is pure - it has no dependencies to load.
    $dependencies = @()
    $dependencies.ForEach{
        if ($sourceMap.ContainsKey($_)) { . $sourceMap[$_] }
        else { Write-Warning "Dependency not found under source: $_" }
    }

    $fileName     = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $functionName = 'Get-AuthHeader'
    . $fileName
}

Describe 'Check Clean Environment' {
    It 'loaded the function from source, not from an imported module' {
        $PSCommandPath.Replace('.Tests.ps1', '.ps1') | Should -Be $fileName
        (Get-Command $functionName).Source | Should -BeNullOrEmpty
    }
}

Describe 'Get-AuthHeader' {
    BeforeAll {
        $cred = [pscredential]::new('ignored-username', (ConvertTo-SecureString 'my-secret-pat' -AsPlainText -Force))
    }

    It 'returns a hashtable carrying an Authorization header' {
        $header = Get-AuthHeader -Credential $cred
        $header        | Should -BeOfType [hashtable]
        $header.Keys   | Should -Contain 'Authorization'
    }

    It 'builds a Basic auth header' {
        (Get-AuthHeader -Credential $cred).Authorization | Should -BeLike 'Basic *'
    }

    It 'encodes an empty username and the PAT as the password' {
        $value   = (Get-AuthHeader -Credential $cred).Authorization
        $b64     = $value -replace '^Basic '
        $decoded = [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($b64))
        $decoded | Should -Be ':my-secret-pat'
    }

    It 'ignores the username - only the PAT matters' {
        $other = [pscredential]::new('someone-else', (ConvertTo-SecureString 'my-secret-pat' -AsPlainText -Force))
        (Get-AuthHeader -Credential $other).Authorization | Should -Be (Get-AuthHeader -Credential $cred).Authorization
    }
}
