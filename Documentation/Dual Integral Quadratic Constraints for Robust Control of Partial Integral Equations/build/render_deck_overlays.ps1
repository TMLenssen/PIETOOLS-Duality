$ErrorActionPreference='Stop'
$dir=Join-Path $PSScriptRoot 'deck_label_overlays'
$report=Get-Content -LiteralPath (Join-Path $dir 'report.json') -Raw | ConvertFrom-Json
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open($report.output,-1,0,0)
try {
    foreach($number in @(1,2,3,4,7,8,9,10,11,12,13,17,25)) {
        $deck.Slides.Item($number).Export((Join-Path $dir ('slide-'+$number+'.png')),'PNG',1920,1080)
    }
    Write-Output 'Rendered all changed slide types.'
} finally { $deck.Close() }
