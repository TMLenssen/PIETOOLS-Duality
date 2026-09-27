$ErrorActionPreference='Stop'
$dir=Join-Path $PSScriptRoot 'deck_label_overlays'
$r=Get-Content -LiteralPath (Join-Path $dir 'report.json') -Raw | ConvertFrom-Json
if ((Get-FileHash -LiteralPath $r.source).Hash -ne $r.source_sha256) { throw 'The presentation has changed since this revision was staged. Rebase before installing.' }
$probe=[IO.File]::Open($r.source,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$probe.Dispose()
$archive=Join-Path (Split-Path -Parent $r.source) ('Archive\Before editable image and video labels '+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $archive -Force | Out-Null
Copy-Item -LiteralPath $r.source -Destination $archive
Copy-Item -LiteralPath $r.output -Destination $r.source -Force
if ((Get-FileHash -LiteralPath $r.source).Hash -ne (Get-FileHash -LiteralPath $r.output).Hash) { throw 'Installed deck hash mismatch.' }
Write-Output ('Updated presentation: '+$r.source)
Write-Output ('Original archived: '+$archive)
