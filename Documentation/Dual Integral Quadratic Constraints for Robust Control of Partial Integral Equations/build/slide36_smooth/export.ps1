$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'static.pptx'),-1,0,0)
try {
 $d.Slides.Item(36).Export((Join-Path $PSScriptRoot 'static.png'),'PNG',2160,1215)
 Write-Output ('Slide size: '+$d.PageSetup.SlideWidth+' x '+$d.PageSetup.SlideHeight)
} finally { $d.Close() }
