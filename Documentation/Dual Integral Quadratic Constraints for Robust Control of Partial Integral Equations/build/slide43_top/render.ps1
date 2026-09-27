$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try {$d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)} finally {$d.Close()}
