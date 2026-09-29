$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'attach.ps1')
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'formatted.pptx'),-1,0,0)
try{
 foreach($i in @(6,13,15,18,21,22,24,34,43,44,45,49,54,75)){
  $s=$d.Slides.Item($i)
  Start-Sleep -Milliseconds 200
  $s.Export((Join-Path $PSScriptRoot ('review{0:D3}.png' -f $i)),'PNG',1440,810)
 }
}finally{$d.Close()}
