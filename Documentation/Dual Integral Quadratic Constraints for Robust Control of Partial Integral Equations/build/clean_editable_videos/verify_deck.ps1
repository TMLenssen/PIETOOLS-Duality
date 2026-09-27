$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try{
 if($deck.Slides.Count -ne 50){throw 'Unexpected final slide count.'}
 $videoCount=0
 foreach($slide in $deck.Slides){
  foreach($shape in $slide.Shapes){
   if($shape.Type -eq 16){
    $videoCount++
    if($shape.MediaFormat.Length -le 0){throw ('Unreadable media on slide '+$slide.SlideIndex)}
   }
  }
 }
 if($videoCount -ne 9){throw ('Expected nine video objects; found '+$videoCount)}
 foreach($n in @(4,13,14,15)){
  $slide=$deck.Slides.Item($n);$plays=0
  foreach($fx in $slide.TimeLine.MainSequence){
   if($fx.EffectType -eq 83){
    if($fx.Timing.TriggerType -ne 2 -or $fx.Timing.TriggerDelayTime -ne 0){throw ('Video is not automatic on slide '+$n)}
    $plays++
   }
  }
  if($plays -ne 1){throw ('Expected one automatic video on slide '+$n)}
 }
 foreach($n in @(2,4,13,14,15,27,28,29)){$deck.Slides.Item($n).Export((Join-Path $PSScriptRoot ('final-slide-'+$n+'.png')),'PNG',1600,900)}
 Write-Output 'Verified 50 slides, nine playable embedded videos, and four immediate autoplay sequences.'
}finally{$deck.Close()}
