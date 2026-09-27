$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'preview.pptx'),-1,0,0)
try {$d.Slides.Item(43).Export((Join-Path $PSScriptRoot 'preview.png'),'PNG',1600,900)} finally {$d.Close()}
