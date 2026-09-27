$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 foreach($i in @(23,24,31,42)){$d.Slides.Item($i).Export((Join-Path $PSScriptRoot ('slide'+$i+'.png')),'PNG',1600,900)}
 $meta=Get-Content (Join-Path $PSScriptRoot 'source.json') -Raw | ConvertFrom-Json
 if($d.Slides.Count -ne $meta.slides){throw 'Slide count changed'}
 foreach($name in @('!!Primal filter matrix','!!Dual filter matrix')){
  $a=$d.Slides.Item(42).Shapes.Item($name);$b=$d.Slides.Item(43).Shapes.Item($name)
  if($a.Left -ne $b.Left -or $a.Width -ne $b.Width -or $a.Height -ne $b.Height){throw 'Morph geometry mismatch'}
 }
 Write-Output 'Verified matching filter dimensions and column alignment.'
} finally {$d.Close()}
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'result.pptx'),-1,0,0)
try {$d.Slides.Item(43).Export((Join-Path $PSScriptRoot 'result.png'),'PNG',1600,900)} finally {$d.Close()}
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'morph.pptx'),0,0,0)
try {
 $d.CreateVideo((Join-Path $PSScriptRoot 'morph.mp4'),$false,2,720,60,85)
 $deadline=(Get-Date).AddSeconds(45)
 while($d.CreateVideoStatus -in @(1,2) -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 300}
 if($d.CreateVideoStatus -ne 3){throw 'Morph preview failed'}
 Write-Output 'Rendered Morph preview at 60 fps.'
} finally {$d.Close()}
