param([string]$AssetDirectory='',[string]$ArchiveLabel='Before baked labels')
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out=Join-Path $workspace 'build\simple_deck'
if($AssetDirectory){$out=(Resolve-Path -LiteralPath $AssetDirectory).Path}
$r=Get-Content -LiteralPath (Join-Path $out 'report.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath $r.source).Hash -ne $r.source_sha256){throw 'Presentation changed since staging; rebase required.'}
$probe=[IO.File]::Open($r.source,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$probe.Dispose()
$archive=Join-Path (Split-Path -Parent $r.source) ('Archive\'+$ArchiveLabel+' '+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $archive -Force | Out-Null
Copy-Item -LiteralPath $r.source -Destination $archive
Copy-Item -LiteralPath $r.output -Destination $r.source -Force
if((Get-FileHash -LiteralPath $r.source).Hash -ne (Get-FileHash -LiteralPath $r.output).Hash){throw 'Installed deck mismatch'}
Write-Output "Installed simplified deck: $($r.source)"
Write-Output "Archived editable original: $archive"
