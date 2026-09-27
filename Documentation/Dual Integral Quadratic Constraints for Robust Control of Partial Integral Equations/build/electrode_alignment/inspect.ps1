$ErrorActionPreference='Stop'
$source=Get-ChildItem -LiteralPath 'C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation' -Filter 'Dual*.pptx' | Select-Object -First 1
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open($source.FullName,-1,0,0)
try {
 foreach($i in @(14,48,49)){
  $s=$d.Slides.Item($i);$s.Export((Join-Path $PSScriptRoot ('slide'+$i+'.png')),'PNG',1600,900)
  Write-Output ('SLIDE '+$i)
  foreach($sh in $s.Shapes){Write-Output ('{0}|{1}|{2:N1},{3:N1},{4:N1},{5:N1}' -f $sh.Id,$sh.Name,$sh.Left,$sh.Top,$sh.Width,$sh.Height)}
 }
} finally {$d.Close()}
