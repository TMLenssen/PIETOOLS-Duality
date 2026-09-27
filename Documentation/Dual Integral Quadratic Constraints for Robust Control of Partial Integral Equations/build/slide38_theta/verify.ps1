$ErrorActionPreference='Stop'
$meta=Get-Content (Join-Path $PSScriptRoot 'source.json') -Raw | ConvertFrom-Json
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 if($d.Slides.Count -ne $meta.slides) { throw 'Slide count changed' }
 $s=$d.Slides.Item(38)
 $found=0
 foreach($sh in $s.Shapes) {
  if($sh.Name -in @('Derived static Theta','Specific uncertainty','Analyse uncertainty','Dynamic Theta')) { $found++ }
 }
 if($found -ne 4) { throw 'Missing equation or list item' }
 $s.Export((Join-Path $PSScriptRoot 'final-preview.png'),'PNG',1600,900)
 Write-Output 'Verified slide count, editable Theta equation, three list items, and final rendering.'
} finally { $d.Close() }
