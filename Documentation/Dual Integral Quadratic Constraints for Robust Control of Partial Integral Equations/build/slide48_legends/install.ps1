$ErrorActionPreference='Stop'
$meta=Get-Content (Join-Path $PSScriptRoot 'source.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath $meta.source).Hash.ToLowerInvariant() -ne $meta.hash) {
 throw 'The original deck changed while editing; refusing to overwrite newer changes.'
}
$probe=[IO.File]::Open($meta.source,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$probe.Dispose()
$archive=Join-Path (Split-Path $meta.source -Parent) ('Archive/Before slide 48 input legend and hand still '+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $archive | Out-Null
Copy-Item -LiteralPath $meta.source -Destination $archive
$final=Join-Path $PSScriptRoot 'final.pptx'
Copy-Item -LiteralPath $final -Destination $meta.source -Force
if((Get-FileHash -LiteralPath $meta.source).Hash -ne (Get-FileHash -LiteralPath $final).Hash) {
 throw 'Installed deck does not match verified deck.'
}
Write-Output ('Saved: '+$meta.source)
Write-Output ('Backup: '+$archive)
