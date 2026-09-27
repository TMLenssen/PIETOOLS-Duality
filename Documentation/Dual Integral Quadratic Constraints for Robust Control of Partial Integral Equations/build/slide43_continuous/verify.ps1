$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 $s=$d.Slides.Item(43);$clicks=0
 foreach($e in $s.TimeLine.MainSequence){if($e.Timing.TriggerType -eq 1){$clicks++}}
 if($clicks -ne 2){throw ('Expected 2 clicks, got '+$clicks)}
 if($s.SlideShowTransition.EntryEffect -ne 3954){throw 'Morph changed'}
 Write-Output 'Verified comparison click, one click for the full derivation, and Morph.'
} finally {$d.Close()}
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
 if($d.CreateVideoStatus -ne 3){throw 'Video export failed'}
 Write-Output 'Rendered the uninterrupted playback at 60 fps.'
} finally {$d.Close()}
