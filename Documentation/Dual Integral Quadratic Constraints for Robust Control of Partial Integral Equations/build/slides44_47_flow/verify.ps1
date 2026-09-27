$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 foreach($i in @(45,46,47)){
  if($d.Slides.Item($i).SlideShowTransition.EntryEffect -ne 3954){throw ('Morph missing on '+$i)}
 }
 Write-Output 'Verified native Morph on all three panel transitions.'
} finally {$d.Close()}
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'preview.pptx'),0,0,0)
try {
 $d.CreateVideo((Join-Path $PSScriptRoot 'preview.mp4'),$false,1,720,30,85)
 $deadline=(Get-Date).AddSeconds(45)
 while($d.CreateVideoStatus -in @(1,2) -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 300}
 if($d.CreateVideoStatus -ne 3){throw 'Preview failed'}
 Write-Output 'Rendered transition preview.'
} finally {$d.Close()}
