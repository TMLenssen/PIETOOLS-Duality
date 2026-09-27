$ErrorActionPreference='Stop'
$meta=Get-Content (Join-Path $PSScriptRoot 'source.json') -Raw | ConvertFrom-Json
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 if($d.Slides.Count -ne $meta.slides) { throw 'Slide count changed' }
 $s=$d.Slides.Item(41)
 foreach($suffix in @('controller relation','filter matrix','transformed signals','expanded inequality','final inequality')) {
  $pair=@()
  foreach($sh in $s.Shapes) { if($sh.Name -in @(('Primal '+$suffix),('Dual '+$suffix))) { $pair+= $sh } }
  if($pair.Count -ne 2) { throw ('Missing matched row '+$suffix) }
  if([Math]::Abs($pair[0].Top-$pair[1].Top) -gt .05 -or [Math]::Abs($pair[0].Width-$pair[1].Width) -gt .05) { throw ('Mismatched row formatting '+$suffix) }
 }
 $s.Export((Join-Path $PSScriptRoot 'final-preview.png'),'PNG',1600,900)
 Write-Output 'Verified slide count, five aligned equation pairs, and final rendering.'
} finally { $d.Close() }
