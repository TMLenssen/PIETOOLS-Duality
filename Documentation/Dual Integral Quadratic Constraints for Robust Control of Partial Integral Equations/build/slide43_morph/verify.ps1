$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 foreach($name in @('!!Primal filter matrix','!!Dual filter matrix')) {
  $null=$d.Slides.Item(42).Shapes.Item($name)
  $null=$d.Slides.Item(43).Shapes.Item($name)
 }
 if($d.Slides.Item(43).TimeLine.MainSequence.Count -ne 10){throw 'Click animations changed'}
 Write-Output ('Morph effect: '+$d.Slides.Item(43).SlideShowTransition.EntryEffect+'; duration: '+$d.Slides.Item(43).SlideShowTransition.Duration)
} finally {$d.Close()}
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'preview.pptx'),0,0,0)
try {
 $d.CreateVideo((Join-Path $PSScriptRoot 'morph.mp4'),$false,2,720,30,85)
 $deadline=(Get-Date).AddSeconds(45)
 while($d.CreateVideoStatus -in @(1,2) -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 300}
 Write-Output ('Video status: '+$d.CreateVideoStatus)
} finally {$d.Close()}
