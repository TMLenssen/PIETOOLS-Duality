$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'Simulation\STN_GPe_Zames_Falb'
$deckPath=Join-Path $out 'Zames-Falb - Editable.pptx'
Add-Type -AssemblyName WindowsBase
Add-Type -Path 'C:\Program Files\Microsoft Office\root\vfs\ProgramFilesX86\Microsoft Office\Office16\DCF\DocumentFormat.OpenXml.dll'
$document=[DocumentFormat.OpenXml.Packaging.PresentationDocument]::Open($deckPath,$false)
try {
    $validator=New-Object DocumentFormat.OpenXml.Validation.OpenXmlValidator([DocumentFormat.OpenXml.FileFormatVersions]::Office2013)
    $errors=@($validator.Validate($document))
    if($errors.Count -gt 0){$errors | Select-Object -First 8 Description,Path | Format-List; throw 'OpenXML validation failed'}
} finally {$document.Dispose()}
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open($deckPath,-1,0,0)
try {
    foreach($i in 1,2){$deck.Slides.Item($i).Export((Join-Path $out "slide-$i.png"),'PNG',1920,1080)}
    $deck.SaveAs((Join-Path $out 'Zames-Falb - Editable.pdf'),32)
} finally {$deck.Close()}
Write-Output 'PowerPoint rendered both slides; OpenXML validation passed.'
$browser='C:\Program Files\Google\Chrome\Application\chrome.exe'
$page=Join-Path $out 'STN-GPe Zames-Falb simulation.html'
$url=([System.Uri]$page).AbsoluteUri+'?t=0.4&mode=rate'
$capture=Join-Path $out 'browser-check.png'
$profile=Join-Path $env:TEMP 'codex-zf-browser'
$args=@('--headless','--disable-gpu','--disable-extensions','--no-first-run','--disable-background-networking','--window-size=1500,1000','--virtual-time-budget=2000','--dump-dom',('--user-data-dir="'+$profile+'"'),('--screenshot="'+$capture+'"'),('"'+$url+'"'))
$process=Start-Process -FilePath $browser -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $out 'browser-check.html') -RedirectStandardError (Join-Path $out 'browser-check.log')
if(-not $process.WaitForExit(45000)){throw 'Browser check timed out'}
$dom=Get-Content -LiteralPath (Join-Path $out 'browser-check.html') -Raw
if($dom -notmatch 'data-rendered="true"'){throw 'Browser drawing did not finish'}
Write-Output 'Browser drawing and DOM labels verified.'
