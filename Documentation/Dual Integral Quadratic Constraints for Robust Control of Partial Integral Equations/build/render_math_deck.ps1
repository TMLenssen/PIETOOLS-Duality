$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'slide33_cleanup'
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open((Join-Path $out 'latex_math.pptx'),-1,0,0)
try {
 foreach($n in @(4,20,29,33,36,38,43)) { $deck.Slides.Item($n).Export((Join-Path $out ('math-slide-'+$n+'.png')),'PNG',1600,900) }
 $fonts=@();foreach($f in $deck.Fonts){$fonts+=$f.Name};$fonts | ConvertTo-Json | Set-Content (Join-Path $out 'fonts.json') -Encoding UTF8
 Write-Output 'Rendered seven representative slides with Latin Modern Math.'
} finally {$deck.Close()}
