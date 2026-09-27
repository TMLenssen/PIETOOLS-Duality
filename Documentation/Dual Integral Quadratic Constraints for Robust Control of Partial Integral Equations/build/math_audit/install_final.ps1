$ErrorActionPreference='Stop'
$meta=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'source.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if((Get-FileHash -LiteralPath $meta.source).Hash -ne $meta.hash){throw 'Presentation changed during editing; refusing to overwrite newer changes.'}
$probe=[IO.File]::Open($meta.source,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$probe.Dispose()
$archive=Join-Path (Split-Path -Parent $meta.source) ('Archive/Before full mathematical rendering review '+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $archive -Force | Out-Null
Copy-Item -LiteralPath $meta.source -Destination $archive
$final=Join-Path $PSScriptRoot 'final.pptx'
Copy-Item -LiteralPath $final -Destination $meta.source -Force
if((Get-FileHash -LiteralPath $meta.source).Hash -ne (Get-FileHash -LiteralPath $final).Hash){throw 'Installed presentation differs from verified presentation.'}
[pscustomobject]@{source=$meta.source;archive=$archive;slides=50;simulations=@(4,13,14,15);videoPostersUpdated=9;sha256=(Get-FileHash -LiteralPath $final).Hash} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'installed.json') -Encoding UTF8
Write-Output ('Saved: '+$meta.source)
Write-Output ('Backup: '+$archive)


