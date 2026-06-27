function Get-MOTreeHash
{
    <#
        .SYNOPSIS
            Computes the canonical tree hash of a directory (the integrity anchor for multi-file assets).

        .DESCRIPTION
            Mirrors the Get-TreeHash reference implementation in the modusops-templates release workflow so a
            consumer can recompute exactly what the library published. For every file under -Path: take its
            repo-relative POSIX path + its SHA256, sort by path, concatenate as "<relpath>`n<sha>`n", and
            SHA256 the UTF8 bytes of that. Used for directory assets whose integrity can't be a single file
            hash (e.g. an issue-template set). Single-file assets and single-file composite actions stay on a
            plain file SHA256; this is only for genuinely multi-file directory content.

            Returns a lowercase hex digest (matching the release checksums.txt), distinct from Get-FileHash's
            uppercase output - callers compare tree hashes to tree hashes and file hashes to file hashes.

        .NOTES
            Author: Adrian Andersson
    #>
    [CmdletBinding()]
    [OutputType([string])]
    PARAM(
        #Directory whose contents are hashed
        [Parameter(Mandatory)]
        [string]$Path
    )
    process{
        $root = (Resolve-Path -LiteralPath $Path).Path
        $files = Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object {
            ([System.IO.Path]::GetRelativePath($root, $_.FullName) -replace '\\','/')
        }
        $sb = [System.Text.StringBuilder]::new()
        foreach($f in $files){
            $rel = ([System.IO.Path]::GetRelativePath($root, $f.FullName) -replace '\\','/')
            $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower()
            [void]$sb.Append("$rel`n$h`n")
        }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try{
            return ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-','').ToLower()
        }finally{
            $sha.Dispose()
        }
    }
}
