$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try {
 $s=$d.Slides.Item(37)
 $seq=$s.TimeLine.MainSequence
 function Fade([string]$name,[int]$trigger) {
  $shape=$null
  foreach($sh in $s.Shapes) { if($sh.Name -eq $name) { $shape=$sh } }
  if($null -eq $shape) { throw ('Missing shape '+$name) }
  $e=$seq.AddEffect($shape,10,0,$trigger)
  $e.Timing.Duration=.35
 }
 Fade 'Sum difference explanation' 1
 Fade 'Transformed gaps' 2
 Fade 'Matrix explanation' 1
 Fade 'Parameterize Theta' 2
 Fade 'Supply identity' 1
 Fade 'Delta dissipativity' 1
 Fade 'Dissipativity meaning' 2
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
 $s.Export((Join-Path $PSScriptRoot 'preview.png'),'PNG',2160,1215)
 Write-Output ('Slide 37 rendered; '+$seq.Count+' effects across four clicks.')
} finally { $d.Close() }
