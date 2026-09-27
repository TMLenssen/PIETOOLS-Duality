$ErrorActionPreference='Stop'
$source=Get-ChildItem -LiteralPath 'C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation' -Filter 'Dual*.pptx' | Select-Object -First 1
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open($source.FullName,-1,0,0)
try {
 foreach($i in @(42,43)) { $d.Slides.Item($i).Export((Join-Path $PSScriptRoot ('slide-'+$i+'.png')),'PNG',2160,1215) }
} finally { $d.Close() }
