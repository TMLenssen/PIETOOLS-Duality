$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$page = Join-Path $workspace 'Presentation\SectorIQC\Simulation\STN_GPe\STN-GPe sector simulation.html'
$capture = Join-Path $PSScriptRoot 'stn_gpe_browser.png'
$profile = Join-Path $PSScriptRoot 'stn_gpe_browser_profile'
$dom = Join-Path $PSScriptRoot 'stn_gpe_browser_dom.html'
$log = Join-Path $PSScriptRoot 'stn_gpe_browser.log'
$browser = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$url = ([System.Uri]$page).AbsoluteUri
$started = Get-Date
$arguments = @('--headless', '--disable-gpu', '--disable-extensions', '--no-first-run', '--no-default-browser-check', '--disable-background-networking', '--window-size=1500,1100', '--virtual-time-budget=2000', '--dump-dom', ('--user-data-dir="' + $profile + '"'), ('--screenshot="' + $capture + '"'), ('"' + $url + '"'))
$process = Start-Process -FilePath $browser -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $dom -RedirectStandardError $log
if (-not $process.WaitForExit(45000)) { throw 'Headless browser did not finish within 45 seconds; check its log.' }
for ($attempt=0; $attempt -lt 100; $attempt++) {
    if ((Test-Path -LiteralPath $capture) -and (Get-Item -LiteralPath $capture).LastWriteTime -ge $started) { break }
    Start-Sleep -Milliseconds 100
}
if (-not (Test-Path -LiteralPath $capture) -or (Get-Item -LiteralPath $capture).LastWriteTime -lt $started) { throw 'Headless browser did not create a fresh screenshot.' }
Write-Output "Browser screenshot: $capture"
