$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 $d.Slides.Item(47).Export((Join-Path $PSScriptRoot 'slide47.png'),'PNG',1600,900)
 foreach($i in 0..6){
  $a=$d.Slides.Item(46).Shapes.Item('!!Contribution line '+$i)
  $b=$d.Slides.Item(47).Shapes.Item('!!Contribution line '+$i)
  if([Math]::Abs($a.Left-$b.Left-436) -gt 0.01){throw 'Contribution sliding distance mismatch'}
 }
 Write-Output 'Verified editable contribution text and continuous slide-in positions.'
} finally {$d.Close()}
