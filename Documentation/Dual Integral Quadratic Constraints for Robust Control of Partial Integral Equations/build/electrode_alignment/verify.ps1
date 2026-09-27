$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 foreach($i in @(14,48,49)){$d.Slides.Item($i).Export((Join-Path $PSScriptRoot ('final'+$i+'.png')),'PNG',1600,900)}
 $ref=$d.Slides.Item(49).Shapes.Item('Controller K block')
 foreach($i in @(14,48)){
  $s=$d.Slides.Item($i).Shapes.Item('Controller K block')
  if($s.Left -ne $ref.Left -or $s.Top -ne $ref.Top){throw 'Controller alignment mismatch'}
 }
 Write-Output 'Rendered all three slides and verified aligned controller positions.'
} finally {$d.Close()}
