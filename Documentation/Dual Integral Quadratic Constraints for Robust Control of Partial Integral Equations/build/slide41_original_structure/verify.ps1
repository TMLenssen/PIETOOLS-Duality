$ErrorActionPreference='Stop'
$meta=Get-Content (Join-Path $PSScriptRoot 'source.json') -Raw | ConvertFrom-Json
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 if($d.Slides.Count -ne $meta.slides) { throw 'Slide count changed' }
 $s=$d.Slides.Item(41)
 foreach($suffix in @('filter matrix','energy inequality','controller relation','final inequality')) {
  $pair=@()
  foreach($sh in $s.Shapes) { if($sh.Name -in @(('Primal '+$suffix),('Dual '+$suffix))) { $pair+=$sh } }
  if($pair.Count -ne 2) { throw ('Missing pair '+$suffix) }
  if([Math]::Abs($pair[0].Top-$pair[1].Top) -gt .05) { throw ('Row misaligned '+$suffix) }
 }
 $s.Export((Join-Path $PSScriptRoot 'final-preview.png'),'PNG',1600,900)
 Write-Output 'Verified original structure, four matching equation rows, and unchanged slide count.'
} finally { $d.Close() }
