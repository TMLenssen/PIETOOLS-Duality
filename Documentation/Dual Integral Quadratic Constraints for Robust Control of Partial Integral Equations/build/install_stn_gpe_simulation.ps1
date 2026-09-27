$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$source = Join-Path $workspace 'Presentation\SectorIQC\Simulation\STN_GPe'
$destination = 'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\Sector IQC - Simulation'
$files = @('STN-GPe sector simulation.html', 'STN-GPe sector simulation.mp4', 'STN-GPe sector simulation.png', 'README.md', 'results.json', 'supply_history.csv', 'stn_gpe_sector_data.npz')
foreach ($name in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $name))) { throw "Missing export: $name" }
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
$backup = Join-Path (Split-Path -Parent $destination) ('Archive\Sector IQC Simulation before simplification ' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
foreach ($name in $files) {
    $target = Join-Path $destination $name
    if (Test-Path -LiteralPath $target) {
        if ((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath (Join-Path $source $name)).Hash) {
            New-Item -ItemType Directory -Path $backup -Force | Out-Null
            Copy-Item -LiteralPath $target -Destination (Join-Path $backup $name)
            Copy-Item -LiteralPath (Join-Path $source $name) -Destination $target -Force
        }
    } else { Copy-Item -LiteralPath (Join-Path $source $name) -Destination $target }
}
Write-Output "Installed simulation exports: $destination"
