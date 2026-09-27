$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 if($d.Slides.Count -ne 56) { throw 'Wrong slide count' }
 $s=$d.Slides.Item(37)
 $seq=$s.TimeLine.MainSequence
 if($seq.Count -ne 7) { throw 'Wrong animation count' }
 $expected=@('Sum difference explanation','Transformed gaps','Matrix explanation','Parameterize Theta','Supply identity','Delta dissipativity','Dissipativity meaning')
 $triggers=@(1,2,1,2,1,1,2)
 for($i=1;$i -le 7;$i++) {
  if($seq.Item($i).Shape.Name -ne $expected[$i-1] -or $seq.Item($i).Timing.TriggerType -ne $triggers[$i-1]) { throw ('Wrong reveal order at '+$i) }
 }
 $s.Export((Join-Path $PSScriptRoot 'final-preview.png'),'PNG',2160,1215)
 Write-Output 'Verified 56 slides, editable matrix, and four clicks: sum/difference, matrix, squared identity, energy interpretation.'
} finally { $d.Close() }
