$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 foreach($i in @(36,37)) { $d.Slides.Item($i).Export((Join-Path $PSScriptRoot ('slide-'+$i+'.png')),'PNG',1600,900) }
 $s=$d.Slides.Item(36)
 if($s.TimeLine.MainSequence.Item(1).Timing.TriggerType -ne 1) { throw 'Playback trigger changed' }
 foreach($sh in $s.Shapes) { if($sh.Type -eq 16 -and $sh.MediaFormat.Length -ne 12000) { throw 'Incorrect video length' } }
 Write-Output 'Both slides rendered; 12-second video and click-to-play verified.'
} finally { $d.Close() }
