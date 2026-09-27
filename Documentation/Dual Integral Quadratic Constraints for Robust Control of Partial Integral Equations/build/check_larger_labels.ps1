$ErrorActionPreference='Stop'
$dir=Join-Path $PSScriptRoot 'larger_labels'
$r=Get-Content (Join-Path $dir 'report.json') -Raw | ConvertFrom-Json
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open($r.output,-1,0,0)
try {
    foreach($i in @(1,2,3,4,10,12,13,25)) {$deck.Slides.Item($i).Export((Join-Path $dir ('slide-'+$i+'.png')),'PNG',1920,1080)}
} finally {$deck.Close()}
Write-Output 'Rendered enlarged labels.'
