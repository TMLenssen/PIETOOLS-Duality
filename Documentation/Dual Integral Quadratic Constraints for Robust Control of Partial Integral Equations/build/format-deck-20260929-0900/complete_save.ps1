$ErrorActionPreference='Stop'
$job=$PSScriptRoot
$meta=Get-Content -LiteralPath (Join-Path $job 'meta.json') -Raw | ConvertFrom-Json
$snapshot=Join-Path $job 'source.pptx'
if((Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash -ne $meta.hash){throw 'Snapshot does not match the original.'}
$formatted=Join-Path $job 'formatted.pptx'
$expected=(Get-FileHash -LiteralPath $formatted -Algorithm SHA256).Hash
if((Get-FileHash -LiteralPath $meta.path -Algorithm SHA256).Hash -ne $expected){throw 'Saved file has changed.'}
$parent=[System.IO.Path]::GetDirectoryName($meta.path)
$archive=Join-Path $parent 'Archive'
if(-not(Test-Path -LiteralPath $archive)){New-Item -ItemType Directory -Path $archive | Out-Null}
$backup=Join-Path $archive ('Presentation - before formatting and numbering '+(Get-Date -Format 'yyyy-MM-dd HHmmss')+'.pptx')
Copy-Item -LiteralPath $snapshot -Destination $backup
if((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $meta.hash){throw 'Backup verification failed.'}
@{path=$meta.path;backup=$backup;hash=$expected}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $job 'saved.json') -Encoding UTF8
Write-Output ('Verified saved deck: '+$meta.path)
Write-Output ('Verified backup: '+$backup)
$extra=Join-Path (Get-Location) ([System.IO.Path]::GetFileName($meta.path))
if((Test-Path -LiteralPath $extra) -and $extra -ne $meta.path){
 if((Get-FileHash -LiteralPath $extra -Algorithm SHA256).Hash -eq $meta.hash){Remove-Item -LiteralPath $extra;Write-Output 'Removed redundant working-directory copy.'}
}
