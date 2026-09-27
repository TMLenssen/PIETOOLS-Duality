$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'slides33_35_signals'
$r=Get-Content -LiteralPath (Join-Path $out 'source.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath $r.source).Hash -ne $r.hash){throw 'The original presentation changed; refusing to overwrite it.'}
$probe=[IO.File]::Open($r.source,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$probe.Dispose()
$archive=Join-Path (Split-Path -Parent $r.source) ('Archive/Before filter signal clarification '+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $archive -Force | Out-Null
Copy-Item -LiteralPath $r.source -Destination $archive
Copy-Item -LiteralPath (Join-Path $out 'final.pptx') -Destination $r.source -Force
if((Get-FileHash -LiteralPath $r.source).Hash -ne (Get-FileHash -LiteralPath (Join-Path $out 'final.pptx')).Hash){throw 'Installed presentation differs from verified revision.'}
[pscustomobject]@{source=$r.source;archive=$archive;slides=45;updated=@(33,34,35);clicks_per_slide=3} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'installed.json') -Encoding UTF8
Write-Output ('Saved: '+$r.source)
Write-Output ('Backup: '+$archive)


