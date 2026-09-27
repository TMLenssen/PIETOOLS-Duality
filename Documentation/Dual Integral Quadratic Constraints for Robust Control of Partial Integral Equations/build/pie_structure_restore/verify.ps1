$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try{
 if($d.Slides.Count -ne 53){throw 'Slide count changed'}
 $videos=0;foreach($s in $d.Slides){foreach($sh in $s.Shapes){if($sh.Type -eq 16){$videos++;if($sh.MediaFormat.Length -le 0){throw 'Unreadable video'}}}}
 if($videos -ne 9){throw 'Video count changed'}
 $clicks=0;$motions=0
 foreach($fx in $d.Slides.Item(20).TimeLine.MainSequence){if($fx.Timing.TriggerType -eq 1){$clicks++};foreach($bh in $fx.Behaviors){if($bh.Type -eq 1){$motions++}}}
 if($clicks -ne 1 -or $motions -ne 1){throw 'Expected one PDE extraction click and motion path'}
 foreach($i in 21..26){$d.Slides.Item($i).Export((Join-Path $PSScriptRoot ('final-'+$i+'.png')),'PNG',1600,900)}
 Write-Output 'Verified 53 slides, nine videos, and native PDE extraction.'
}finally{$d.Close()}
$v=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'playback-check.pptx'),0,0,0)
try{
 $v.CreateVideo((Join-Path $PSScriptRoot 'playback.mp4'),$false,3,720,30,85)
 $deadline=(Get-Date).AddMinutes(2)
 while($v.CreateVideoStatus -in @(1,2)){
  if((Get-Date) -gt $deadline){throw 'Playback timeout'}
  Start-Sleep -Milliseconds 500
 }
 if($v.CreateVideoStatus -ne 3){throw 'Playback export failed'}
 Write-Output 'Exported extraction playback.'
}finally{$v.Close()}
