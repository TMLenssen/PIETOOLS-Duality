$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try{
 $expected=(Get-Content (Join-Path $PSScriptRoot 'parts.json') -Raw | ConvertFrom-Json).Count
 if($d.Slides.Count -ne $expected){throw 'Slide count changed'}
 foreach($i in 20..26){$d.Slides.Item($i).Export((Join-Path $PSScriptRoot ('after-'+$i+'.png')),'PNG',1600,900)}
 $videos=0;foreach($s in $d.Slides){foreach($sh in $s.Shapes){if($sh.Type -eq 16){$videos++;if($sh.MediaFormat.Length -le 0){throw 'Unreadable video'}}}}
 if($videos -ne 9){throw 'Video count changed'}
 Write-Output ($d.Slides.Count.ToString()+' slides; '+$videos+' working videos; transition 26='+$d.Slides.Item(26).SlideShowTransition.EntryEffect)
}finally{$d.Close()}
$v=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'transition-check.pptx'),0,0,0)
try{
 $v.CreateVideo((Join-Path $PSScriptRoot 'transition.mp4'),$false,2,720,30,85)
 $deadline=(Get-Date).AddMinutes(2)
 while($v.CreateVideoStatus -in @(1,2)){
  if((Get-Date) -gt $deadline){throw 'Video rendering timeout'}
  Start-Sleep -Milliseconds 500
 }
 if($v.CreateVideoStatus -ne 3){throw ('Transition export failed: '+$v.CreateVideoStatus)}
 Write-Output 'Rendered the native 25-to-26 transition.'
}finally{$v.Close()}
