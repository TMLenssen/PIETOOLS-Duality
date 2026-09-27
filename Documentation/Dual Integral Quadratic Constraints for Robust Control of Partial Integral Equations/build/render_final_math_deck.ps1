$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'slide33_cleanup'
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open((Join-Path $out 'final_math.pptx'),-1,0,0)
try {
 foreach($n in @(4,7,8,9,10,11,12,18,20,21,22,23,29,30,31,33,36,37,38,39,40,41,42,43)) { $deck.Slides.Item($n).Export((Join-Path $out ('final-slide-'+$n+'.png')),'PNG',1280,720) }
 Write-Output 'Rendered all 24 slides containing editable equations.'
} finally {$deck.Close()}
