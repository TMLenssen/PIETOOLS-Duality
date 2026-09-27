$ErrorActionPreference='Stop'
$meta=Get-Content (Join-Path $PSScriptRoot 'source.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath $meta.source).Hash -ne $meta.hash){throw 'Source presentation changed during editing; refusing to overwrite newer edits.'}
$probe=[IO.File]::Open($meta.source,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$probe.Dispose()
$archive=Join-Path (Split-Path $meta.source -Parent) ('Archive/Before animated LFR construction '+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $archive -Force | Out-Null
Copy-Item -LiteralPath $meta.source -Destination $archive
$final=Join-Path $PSScriptRoot 'final.pptx'
Copy-Item -LiteralPath $final -Destination $meta.source -Force
if((Get-FileHash -LiteralPath $meta.source).Hash -ne (Get-FileHash -LiteralPath $final).Hash){throw 'Installed deck differs from verified deck.'}
[pscustomobject]@{source=$meta.source;archive=$archive;slides=52;animatedSlide=19;clicks=4;closingSlide=43;sha256=(Get-FileHash -LiteralPath $final).Hash} | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot 'installed.json') -Encoding UTF8
Write-Output ('Saved: '+$meta.source)
Write-Output ('Backup: '+$archive)
