$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$r=Get-Content -LiteralPath (Join-Path $workspace 'build\iqc_final\report.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath $r.source).Hash -ne $r.source_sha256){throw 'Presentation changed since staging; rebase before installation.'}
$probe=[IO.File]::Open($r.source,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$probe.Dispose()
$archive=Join-Path (Split-Path -Parent $r.source) ('Archive\Before Zames-Falb simulation '+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $archive -Force | Out-Null
Copy-Item -LiteralPath $r.source -Destination $archive
Copy-Item -LiteralPath $r.output -Destination $r.source -Force
if((Get-FileHash -LiteralPath $r.source).Hash -ne (Get-FileHash -LiteralPath $r.output).Hash){throw 'Installed deck hash mismatch'}
& (Join-Path $PSScriptRoot 'install_zames_falb.ps1')
& (Join-Path $workspace 'build\install_stn_gpe_simulation.ps1')
Write-Output 'Installed the presentation and both simulation libraries. Original presentation archived.'
