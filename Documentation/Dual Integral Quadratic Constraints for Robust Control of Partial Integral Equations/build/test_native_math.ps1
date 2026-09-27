$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'slide33_cleanup'
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open((Join-Path $out 'cleaned.pptx'),0,0,0)
try {
 $deck.Fonts.Replace('Cambria Math','Latin Modern Math')
 $deck.SaveAs((Join-Path $out 'native_math.pptx'))
 foreach($n in @(20,21,33,38)){$deck.Slides.Item($n).Export((Join-Path $out ('native'+$n+'.png')),'PNG',1600,900)}
 Write-Output 'Tested native PowerPoint font replacement.'
} finally {$deck.Close()}
