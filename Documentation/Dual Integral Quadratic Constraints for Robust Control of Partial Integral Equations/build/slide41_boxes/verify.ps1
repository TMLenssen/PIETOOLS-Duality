$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
foreach($name in @('preview','final')) {
 $d=$ppt.Presentations.Open((Join-Path $PSScriptRoot ($name+'.pptx')),-1,0,0)
 try {
  $s=$d.Slides.Item(41)
  if($name -eq 'preview') { $s.Export((Join-Path $PSScriptRoot 'preview.png'),'PNG',1600,900) }
  else {
   $count=0
   foreach($e in $s.TimeLine.MainSequence) {
    if($e.Shape.Name -like '*final inequality red box') {
     if($e.Timing.TriggerType -ne 2 -or [Math]::Abs($e.Timing.TriggerDelayTime-.55) -gt .001) {throw 'Wrong box timing'}
     $count++
    }
   }
   if($count -ne 2) { throw 'Missing red-box animations' }
   Write-Output 'Verified two red boxes, each delayed until after the equation movement, with no extra click.'
  }
 } finally {$d.Close()}
}
