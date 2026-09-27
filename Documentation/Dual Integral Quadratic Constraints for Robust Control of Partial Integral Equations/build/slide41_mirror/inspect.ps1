$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'source.pptx'),-1,0,0)
try {
 foreach($i in @(41,42)) { $d.Slides.Item($i).Export((Join-Path $PSScriptRoot ('source-'+$i+'.png')),'PNG',2160,1215) }
} finally { $d.Close() }
