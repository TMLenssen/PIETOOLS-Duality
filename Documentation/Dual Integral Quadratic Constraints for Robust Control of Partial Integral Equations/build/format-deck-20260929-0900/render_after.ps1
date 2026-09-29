$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'attach.ps1')
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'formatted.pptx'),-1,0,0)
try{
  foreach($s in $d.Slides){
    $s.Export((Join-Path $PSScriptRoot ('after{0:D3}.png' -f $s.SlideIndex)),'PNG',960,540)
  }
  Write-Output ('Rendered '+$d.Slides.Count+' slides in PowerPoint.')
}finally{$d.Close()}
