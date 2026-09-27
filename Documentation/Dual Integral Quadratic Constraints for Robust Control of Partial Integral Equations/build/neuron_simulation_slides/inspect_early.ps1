$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'source_exact.pptx'),-1,0,0)
try{foreach($n in @(4,5,6,15,16,17)){$deck.Slides.Item($n).Export((Join-Path $PSScriptRoot ('early-'+$n+'.png')),'PNG',1200,675)}}finally{$deck.Close()}
