$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'slides33_35_closure'
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open((Join-Path $out 'staged.pptx'),0,0,0)
try {
 foreach($n in @(33,34,35,36)) {
  $slide=$deck.Slides.Item($n)
  for($i=$slide.TimeLine.MainSequence.Count;$i -ge 1;$i--){$slide.TimeLine.MainSequence.Item($i).Delete()}
  foreach($stage in @(1,2,3)){
   $first=$true
   foreach($s in $slide.Shapes){
    if($s.Name.StartsWith('Stage'+$stage+' ')){
     $trigger=2;if($first){$trigger=1;$first=$false}
     $effect=$slide.TimeLine.MainSequence.AddEffect($s,10,0,$trigger)
     $effect.Timing.Duration=0.3
    }
   }
  }
  $slide.Export((Join-Path $out ('after-'+$n+'.png')),'PNG',1600,900)
  Write-Output ('Slide '+$n+': '+$slide.Shapes.Count+' shapes; '+$slide.TimeLine.MainSequence.Count+' fade effects.')
 }
 $deck.SaveAs((Join-Path $out 'animated.pptx'))
}finally{$deck.Close()}




