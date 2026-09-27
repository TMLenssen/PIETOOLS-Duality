$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'source.pptx'),-1,0,0)
try {
 $s=$d.Slides.Item(2)
 $s.Export((Join-Path $PSScriptRoot 'source.png'),'PNG',2160,1215)
 for($i=1;$i -le $s.TimeLine.MainSequence.Count;$i++) {
  $e=$s.TimeLine.MainSequence.Item($i)
  Write-Output ('Effect '+$i+' '+$e.Shape.Name+' trigger '+$e.Timing.TriggerType+' duration '+$e.Timing.Duration)
 }
} finally { $d.Close() }
