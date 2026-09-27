$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'static.pptx'),0,0,0)
try {
 $s=$d.Slides.Item(36)
 for($k=$s.Shapes.Count;$k -ge 1;$k--) {
  if($s.Shapes.Item($k).Name -eq '!!Sector plot') { $s.Shapes.Item($k).Delete() }
 }
 $s.SlideShowTransition.EntryEffect=0
 $s.SlideShowTransition.AdvanceOnTime=0
 $s.SlideShowTransition.AdvanceOnClick=-1
 $movie=$s.Shapes.AddMediaObject2((Join-Path $PSScriptRoot 'gaps-60fps.mp4'),0,-1,35,64,660,320)
 $movie.Name='Smooth sector gaps - click to play'
 $movie.MediaFormat.SetDisplayPictureFromFile((Join-Path $PSScriptRoot 'frame-0.png'))
 $movie.AnimationSettings.PlaySettings.HideWhileNotPlaying=0
 $movie.AnimationSettings.PlaySettings.RewindMovie=0
 $movie.AnimationSettings.PlaySettings.LoopUntilStopped=0
 $movie.ZOrder(1)
 $seq=$s.TimeLine.MainSequence
 for($k=$seq.Count;$k -ge 1;$k--) { $seq.Item($k).Delete() }
 $effect=$seq.AddEffect($movie,83,0,1)
 $effect.Timing.TriggerDelayTime=0
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
 $s.Export((Join-Path $PSScriptRoot 'preview.png'),'PNG',2160,1215)
 Write-Output ('Video duration: '+$movie.MediaFormat.Length+' ms; effects: '+$seq.Count+'; trigger: '+$effect.Timing.TriggerType)
} finally { $d.Close() }
