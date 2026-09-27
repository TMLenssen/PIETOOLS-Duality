$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 $s=$d.Slides.Item(48)
 $null=$s.Shapes.Item('Still hand from slide 14')
 foreach($name in @('Input plot legend control text','Input plot legend disturbance S','Input plot legend disturbance G')){$null=$s.Shapes.Item($name)}
 $s.Export((Join-Path $PSScriptRoot 'final.png'),'PNG',1600,900)
 Write-Output 'Verified static hand image and all three editable legend entries.'
} finally {$d.Close()}
