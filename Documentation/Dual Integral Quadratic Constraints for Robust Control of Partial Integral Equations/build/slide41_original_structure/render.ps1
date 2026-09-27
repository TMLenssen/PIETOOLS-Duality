$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try {
 $d.Slides.Item(41).Export((Join-Path $PSScriptRoot 'preview.png'),'PNG',2160,1215)
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
 Write-Output 'Rendered slide 41 with editable equations.'
} finally { $d.Close() }
