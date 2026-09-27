$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try{
 if($d.Slides.Count -ne 52){throw 'Expected 52 slides.'}
 $s=$d.Slides.Item(19);$clicks=0;$motions=0
 foreach($fx in $s.TimeLine.MainSequence){
  if($fx.Timing.TriggerType -eq 1){$clicks++}
  foreach($beh in $fx.Behaviors){if($beh.Type -eq 1){$motions++}}
 }
 if($clicks -ne 4 -or $motions -ne 4){throw 'Expected four clicks and four motion paths.'}
 $videos=0;foreach($slide in $d.Slides){foreach($sh in $slide.Shapes){if($sh.Type -eq 16){$videos++;if($sh.MediaFormat.Length -le 0){throw 'Unreadable video'}}}}
 if($videos -ne 9){throw 'Expected nine existing videos.'}
 $d.Slides.Item(43).Export((Join-Path $PSScriptRoot 'closing.png'),'PNG',1600,900)
 Write-Output 'Verified 52 slides, four click stages, four motion paths, nine original videos.'
}finally{$d.Close()}
$v=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'playback-check.pptx'),0,0,0)
try{
 $v.CreateVideo((Join-Path $PSScriptRoot 'playback.mp4'),$false,3,720,30,85)
 $deadline=(Get-Date).AddMinutes(3)
 while($v.CreateVideoStatus -in @(1,2)){
  if((Get-Date) -gt $deadline){throw 'Video rendering timeout'}
  Start-Sleep -Milliseconds 500
 }
 if($v.CreateVideoStatus -ne 3){throw ('PowerPoint video export failed: '+$v.CreateVideoStatus)}
 Write-Output 'Exported real PowerPoint animation playback.'
}finally{$v.Close()}
