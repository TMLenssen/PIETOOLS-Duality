$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try{
 if($d.Slides.Count -ne 56){throw 'Wrong slide count'}
 $videos=0;foreach($s in $d.Slides){foreach($sh in $s.Shapes){if($sh.Type -eq 16){$videos++;if($sh.MediaFormat.Length -le 0){throw 'Unreadable video'}}}}
 if($videos -ne 10){throw ('Video count '+$videos)}
 if($d.Slides.Item(34).SlideShowTransition.EntryEffect -ne 3954){throw 'Missing Delta Morph'}
 Write-Output '56 slides, all ten videos readable; Delta Morph verified.'
}finally{$d.Close()}
foreach($name in @('zoom','gaps','filter','stability')){
 $v=$ppt.Presentations.Open((Join-Path $PSScriptRoot ($name+'-check.pptx')),0,0,0)
 try{
  $v.CreateVideo((Join-Path $PSScriptRoot ($name+'.mp4')),$false,3,720,24,85)
  $deadline=(Get-Date).AddMinutes(3)
  while($v.CreateVideoStatus -in @(1,2)){
   if((Get-Date) -gt $deadline){throw 'Video export timeout'}
   Start-Sleep -Milliseconds 500
  }
  if($v.CreateVideoStatus -ne 3){throw 'Video export failed'}
  Write-Output ('Rendered '+$name+' playback.')
 }finally{$v.Close()}
}
