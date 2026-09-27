$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'slide33_cleanup'
$r=Get-Content -LiteralPath (Join-Path $out 'source.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath $r.source).Hash -ne $r.hash){throw 'The source presentation changed; refusing to overwrite it.'}
$probe=[IO.File]::Open($r.source,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$probe.Dispose()
$archive=Join-Path (Split-Path -Parent $r.source) ('Archive/Before slide 33 cleanup '+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $archive -Force | Out-Null
Copy-Item -LiteralPath $r.source -Destination $archive
Copy-Item -LiteralPath (Join-Path $out 'cleaned.pptx') -Destination $r.source -Force
if((Get-FileHash -LiteralPath $r.source).Hash -ne (Get-FileHash -LiteralPath (Join-Path $out 'cleaned.pptx')).Hash){throw 'Installed presentation hash mismatch.'}
[pscustomobject]@{source=$r.source;archive=$archive;hash=(Get-FileHash -LiteralPath $r.source).Hash;math_font_change='Not installed because native rendering is incorrect'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'installed.json') -Encoding UTF8
Write-Output ('Updated slide 33: '+$r.source)
Write-Output ('Original archived: '+$archive)
