$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try {
 $s=$d.Slides.Item(2); $seq=$s.TimeLine.MainSequence
 function FindShape([string]$name) {
  foreach($sh in $s.Shapes) { if($sh.Name -eq $name) { return $sh } }
  throw ('Missing '+$name)
 }
 $e=$seq.AddEffect((FindShape 'Additional flexible modes - body springs'),10,0,1)
 $e.Timing.Duration=.9
 $e.MoveTo(2)
 $e=$seq.AddEffect((FindShape 'Flexible modes caption'),10,0,2)
 $e.Timing.Duration=.9
 $e.MoveTo(3)
 $highlights=Get-Content (Join-Path $PSScriptRoot 'highlights.json') -Raw | ConvertFrom-Json
 foreach($h in $highlights) {
  $e=$seq.AddEffect((FindShape $h.original),1,0,2)
  $e.Exit=-1
  $e.Timing.Duration=.01
  $e=$seq.AddEffect((FindShape $h.new),10,0,2)
  $e.Timing.Duration=.35
 }
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
 $s.Export((Join-Path $PSScriptRoot 'preview.png'),'PNG',2160,1215)
 for($i=1;$i -le $seq.Count;$i++) {
  $e=$seq.Item($i)
  Write-Output ($i.ToString()+' '+$e.Shape.Name+' trigger '+$e.Timing.TriggerType+' duration '+$e.Timing.Duration)
 }
} finally { $d.Close() }
