$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'attach.ps1')
foreach($file in @('source','formatted')){
 $d=$ppt.Presentations.Open((Join-Path $PSScriptRoot ($file+'.pptx')),-1,0,-1)
 try{
  foreach($i in @(13,34,43)){
   $d.Windows.Item(1).View.GotoSlide($i)
   Start-Sleep -Milliseconds 500
   $d.Slides.Item($i).Export((Join-Path $PSScriptRoot ($file+'-check'+$i+'.png')),'PNG',1440,810)
  }
 }finally{$d.Close()}
}
