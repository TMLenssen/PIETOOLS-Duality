$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try{
 $meta=Get-Content (Join-Path $PSScriptRoot 'source.json') -Raw | ConvertFrom-Json
 if($d.Slides.Count -ne $meta.slides){throw 'Slide count changed'}
 $videos=0;foreach($s in $d.Slides){foreach($sh in $s.Shapes){if($sh.Type -eq 16){$videos++;if($sh.MediaFormat.Length -le 0){throw 'Unreadable video'}}}}
 if($videos -ne 9){throw 'Video count changed'}
 foreach($i in 22..25){$d.Slides.Item($i).Export((Join-Path $PSScriptRoot ('final-'+$i+'.png')),'PNG',1600,900)}
 if($d.Slides.Item(25).SlideShowTransition.EntryEffect -ne 3954){throw 'Pillar transition is not Morph'}
 Write-Output ($d.Slides.Count.ToString()+' slides; nine videos; native Morph on 25.')
}finally{$d.Close()}
foreach($name in @('operators','pillars')){
 $v=$ppt.Presentations.Open((Join-Path $PSScriptRoot ($name+'-check.pptx')),0,0,0)
 try{
  $v.CreateVideo((Join-Path $PSScriptRoot ($name+'.mp4')),$false,3,720,30,85)
  $deadline=(Get-Date).AddMinutes(2)
  while($v.CreateVideoStatus -in @(1,2)){
   if((Get-Date) -gt $deadline){throw 'Video export timeout'}
   Start-Sleep -Milliseconds 500
  }
  if($v.CreateVideoStatus -ne 3){throw 'Video export failed'}
  Write-Output ('Rendered '+$name+' transition.')
 }finally{$v.Close()}
}
