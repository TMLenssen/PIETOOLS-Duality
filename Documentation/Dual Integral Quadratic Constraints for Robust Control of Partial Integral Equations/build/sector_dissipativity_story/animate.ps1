$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try {
 function FindShape([string]$name){foreach($sh in $s.Shapes){if($sh.Name -eq $name){return $sh}};throw ('Missing '+$name)}
 function Fade([string]$name,[bool]$exit,[int]$trigger,[double]$delay,[double]$duration){
  $e=$seq.AddEffect((FindShape $name),10,0,$trigger);$e.Exit=[int](-[int]$exit);$e.Timing.Duration=$duration;$e.Timing.TriggerDelayTime=$delay
 }
 function MoveShape([string]$name,[double]$x,[double]$y,[double]$scale,[int]$trigger,[double]$delay,[double]$duration){
  $sh=FindShape $name;$dx=($x-$sh.Left-$sh.Width/2)/720;$dy=($y-$sh.Top-$sh.Height/2)/405
  $e=$seq.AddEffect($sh,0,0,$trigger);$e.Timing.Duration=$duration;$e.Timing.TriggerDelayTime=$delay
  $mo=$e.Behaviors.Add(1);$mo.MotionEffect.Path=('M 0 0 L '+$dx.ToString('0.########',[Globalization.CultureInfo]::InvariantCulture)+' '+$dy.ToString('0.########',[Globalization.CultureInfo]::InvariantCulture)+' E')
  $sc=$e.Behaviors.Add(3);$sc.ScaleEffect.FromX=100;$sc.ScaleEffect.FromY=100;$sc.ScaleEffect.ToX=$scale;$sc.ScaleEffect.ToY=$scale
  $e.Timing.SmoothStart=-1;$e.Timing.SmoothEnd=-1
 }
 $s=$d.Slides.Item(34);$seq=$s.TimeLine.MainSequence
 $e=$seq.AddEffect((FindShape 'Shifted sigmoid curve'),22,0,2);$e.EffectParameters.Direction=4;$e.Timing.Duration=1.2;$e.Timing.TriggerDelayTime=.2
 $trigger=1
 foreach($sh in $s.Shapes){if($sh.Name -like 'Sector bounds*'){$e=$seq.AddEffect($sh,10,0,$trigger);$e.Timing.Duration=.5;$trigger=2}}
 foreach($nm in @('Upper boundary label','Lower boundary label','Sector condition','Sector values','Shifted explanation')){Fade $nm $false 2 0 .5}
 if($s.SlideShowTransition.EntryEffect -ne 3954){throw 'Delta zoom transition is not Morph'}
 $s=$d.Slides.Item(35);$seq=$s.TimeLine.MainSequence
 $movie=$s.Shapes.AddMediaObject2((Join-Path $PSScriptRoot 'signed_gaps.mp4'),0,-1,38,80,300,220)
 $movie.Name='Signed sector gaps';$movie.MediaFormat.SetDisplayPictureFromFile((Join-Path $PSScriptRoot 'signed_gaps.png'))
 $movie.AnimationSettings.PlaySettings.HideWhileNotPlaying=0;$movie.AnimationSettings.PlaySettings.RewindMovie=-1;$movie.AnimationSettings.PlaySettings.LoopUntilStopped=0
 $movie.ZOrder(1)
 $e=$seq.AddEffect($movie,83,0,2,1);$e.Timing.TriggerDelayTime=0
 Fade 'Positive input' $false 2 .15 .2
 Fade 'Positive input' $true 2 5.85 .15
 Fade 'Negative input' $false 2 6.15 .2
 Fade 'Negative input' $true 2 11.8 .2
 $s=$d.Slides.Item(36);$seq=$s.TimeLine.MainSequence
 Fade 'Supply identity' $false 1 0 .6
 Fade 'Delta dissipativity' $false 1 0 .6
 Fade 'Dissipativity meaning' $false 2 .2 .5
 $s=$d.Slides.Item(37);$seq=$s.TimeLine.MainSequence
 MoveShape 'Construct Theta' 492 130 20 1 0 1.1
 Fade 'Filtered signals' $true 2 0 .45
 Fade 'Filter role' $true 2 0 .45
 Fade 'Construct Theta' $true 2 .8 .3
 Fade 'Connected LFR' $false 2 .8 .65
 $s=$d.Slides.Item(40);$seq=$s.TimeLine.MainSequence
 foreach($nm in @('Sector condition for stability','Uniform plant certificate')){Fade $nm $false $(if($nm -eq 'Sector condition for stability'){1}else{2}) 0 .5}
 Fade 'Closed loop decay' $false 1 0 .5
 Fade 'Coercive storage and rate' $false 2 .35 .5
 Fade 'Robust conclusion' $false 2 .6 .5
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
 foreach($i in @(33,34,35,36,37,39,40)){$d.Slides.Item($i).Export((Join-Path $PSScriptRoot ('render-'+$i+'.png')),'PNG',1600,900)}
 Write-Output 'Added Delta zoom, sector reveal, animated signed gaps, dissipativity build, and Theta-to-LFR transition.'
}finally{$d.Close()}
