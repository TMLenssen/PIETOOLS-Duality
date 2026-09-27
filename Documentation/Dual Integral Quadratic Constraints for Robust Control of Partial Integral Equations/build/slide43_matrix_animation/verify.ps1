$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
foreach($stage in @(0,1,2,3)){
 $d=$ppt.Presentations.Open((Join-Path $PSScriptRoot ('stage'+$stage+'.pptx')),-1,0,0)
 try {$d.Slides.Item(43).Export((Join-Path $PSScriptRoot ('stage'+$stage+'.png')),'PNG',1600,900)} finally {$d.Close()}
}
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'movie.pptx'),0,0,0)
try {
 $s=$d.Slides.Item(1)
 foreach($e in $s.TimeLine.MainSequence){
  if($e.Timing.TriggerType -eq 1){$e.Timing.TriggerType=3;$e.Timing.TriggerDelayTime=0}
 }
 $s.SlideShowTransition.AdvanceOnTime=-1;$s.SlideShowTransition.AdvanceTime=17
 $d.CreateVideo((Join-Path $PSScriptRoot 'animation.mp4'),$true,17,720,60,85)
 $deadline=(Get-Date).AddSeconds(45)
 while($d.CreateVideoStatus -in @(1,2) -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 300}
 Write-Output ('Animation video status: '+$d.CreateVideoStatus)
} finally {$d.Close()}
