$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'source_exact.pptx'),0,0,0)
try {
 $copy=$deck.Slides.Item(14).Duplicate();$copy.Item(1).MoveTo(15)
 foreach($n in @(4,13,14,15)) {
  $slide=$deck.Slides.Item($n)
  for($i=$slide.TimeLine.MainSequence.Count;$i -ge 1;$i--){$slide.TimeLine.MainSequence.Item($i).Delete()}
  $remove=@(70,76);$name='healthy'
  if($n -eq 4){$remove=@(18,3);$name='delta'}
  if($n -eq 14){$remove=@(78,80);$name='parkinsonian'}
  if($n -eq 15){$remove=@(78,80);$name='controlled'}
  for($i=$slide.Shapes.Count;$i -ge 1;$i--){if($remove -contains $slide.Shapes.Item($i).Id){$slide.Shapes.Item($i).Delete()}}
  if($n -eq 4){$left=80;$top=204;$width=590;$height=590*540/1920}
  else {$left=34.5;$top=88;$width=666;$height=666*740/1920}
  $movie=$slide.Shapes.AddMediaObject2((Join-Path $PSScriptRoot ($name+'.mp4')),0,-1,$left,$top,$width,$height)
  $movie.Name='Simulation - '+$name
  $movie.MediaFormat.SetDisplayPictureFromFile((Join-Path $PSScriptRoot ($name+'-start.png')))
  $movie.AnimationSettings.PlaySettings.HideWhileNotPlaying=0
  $movie.AnimationSettings.PlaySettings.RewindMovie=-1
  $movie.AnimationSettings.PlaySettings.LoopUntilStopped=0
  if($n -eq 4){$movie.AnimationSettings.PlaySettings.LoopUntilStopped=-1}
  $effect=$slide.TimeLine.MainSequence.AddEffect($movie,83,0,2,1)
  $effect.Timing.TriggerDelayTime=0
  if($n -eq 14){$slide.Shapes.Item('Title 1').TextFrame.TextRange.Text='Beta-oscillations'}
  if($n -eq 15){
   $slide.Shapes.Item('Title 1').TextFrame.TextRange.Text='Feedback stabilization'
   $slide.Shapes.Item('TextBox 67').TextFrame.TextRange.Text='Paper controller: external pulse at 0.10-0.14 s; dashed trajectories show controller off.'
   $slide.Shapes.Item('TextBox 67').Width=645
   $slide.Shapes.Item('TextBox 67').TextFrame.TextRange.Font.Size=10
  }
  foreach($s in $slide.Shapes){if($s.Name -eq 'Slide Number Placeholder 5'){$s.TextFrame.TextRange.Text=[string]$n}}
  $slide.Export((Join-Path $PSScriptRoot ('com-slide-'+$n+'.png')),'PNG',1600,900)
  Write-Output ('Slide '+$n+': '+$movie.Name+'; duration '+$movie.MediaFormat.Length+' ms; automatic play effect '+$effect.EffectType)
 }
 $deck.SaveAs((Join-Path $PSScriptRoot 'com-edited.pptx'))
}finally{$deck.Close()}
