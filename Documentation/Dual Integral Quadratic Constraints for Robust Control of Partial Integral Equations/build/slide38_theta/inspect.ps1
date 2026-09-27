$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'source.pptx'),-1,0,0)
try { $d.Slides.Item(38).Export((Join-Path $PSScriptRoot 'source.png'),'PNG',1600,900) } finally { $d.Close() }
