$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try {
 $s=$d.Slides.Item(43)
 $seq=$s.TimeLine.MainSequence
 $comparison=@('Transpose comparison','Transpose explanation')
 $result=@('Dual operation arrow','Dual operation arrow label','Dual operation steps','Dual operation result box','Dual operation definition','Dual operation evaluation')
 $first=$true
 foreach($name in $comparison) {
  $trigger=2; if($first) {$trigger=1; $first=$false}
  $e=$seq.AddEffect($s.Shapes.Item($name),10,0,$trigger); $e.Timing.Duration=0.4
 }
 $first=$true
 foreach($name in $comparison) {
  $trigger=2; if($first) {$trigger=1; $first=$false}
  $e=$seq.AddEffect($s.Shapes.Item($name),10,0,$trigger); $e.Exit=-1; $e.Timing.Duration=0.3
 }
 foreach($name in $result) {
  $e=$seq.AddEffect($s.Shapes.Item($name),10,0,2); $e.Timing.Duration=0.4; $e.Timing.TriggerDelayTime=0.3
 }
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
 Write-Output ('Saved editable slide with '+$seq.Count+' effects.')
} finally {$d.Close()}
