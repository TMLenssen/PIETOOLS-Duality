$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try{
 function FindShape([string]$name){foreach($sh in $s.Shapes){if($sh.Name -eq $name){return $sh}};throw ('Missing '+$name)}
 function Fade([string]$name,[bool]$exit,[int]$trigger,[double]$delay,[double]$duration){
  $e=$seq.AddEffect((FindShape $name),10,0,$trigger);$e.Exit=[int](-[int]$exit);$e.Timing.Duration=$duration;$e.Timing.TriggerDelayTime=$delay
 }
 $s=$d.Slides.Item(34);$seq=$s.TimeLine.MainSequence
 $e=$seq.AddEffect((FindShape '!!Sector plot'),22,0,2);$e.EffectParameters.Direction=4;$e.Timing.Duration=1.2;$e.Timing.TriggerDelayTime=.2
 Fade 'Initial map' $true 1 0 .25
 Fade 'Original paper schematic' $false 2 0 .7
 Fade 'Introduce Theta' $false 2 .3 .5
 $trigger=1
 foreach($sh in $s.Shapes){if($sh.Name -like 'Sector bounds*'){$e=$seq.AddEffect($sh,10,0,$trigger);$e.Timing.Duration=.5;$trigger=2}}
 foreach($nm in @('Upper boundary label','Lower boundary label','Sector condition')){Fade $nm $false 2 0 .5}
 $s=$d.Slides.Item(35);$seq=$s.TimeLine.MainSequence
 $movie=$s.Shapes.AddMediaObject2((Join-Path $PSScriptRoot 'signed_gaps.mp4'),0,-1,50,78,620,225)
 $movie.Name='Signed gaps with numerical readouts';$movie.MediaFormat.SetDisplayPictureFromFile((Join-Path $PSScriptRoot 'signed_gaps.png'))
 $movie.AnimationSettings.PlaySettings.HideWhileNotPlaying=0;$movie.AnimationSettings.PlaySettings.RewindMovie=0;$movie.AnimationSettings.PlaySettings.LoopUntilStopped=0
 $movie.ZOrder(1)
 Fade '!!Sector plot' $true 2 .15 .2
 Fade 'Signed gaps with numerical readouts' $false 2 .15 .2
 $e=$seq.AddEffect($movie,83,0,2);$e.Timing.TriggerDelayTime=.4
 $read=Get-Content (Join-Path $PSScriptRoot 'readouts.json') -Raw | ConvertFrom-Json
 for($k=0;$k -lt $read.values.Count;$k++){
  $nm='Readout '+$k.ToString('000');$start=.4+$k/$read.fps
  Fade $nm $false 2 $start .001
  if($k -lt $read.values.Count-1){Fade $nm $true 2 ($start+1/$read.fps) .001}
 }
 $s=$d.Slides.Item(36);$seq=$s.TimeLine.MainSequence
 Fade 'Transformed gaps' $false 1 0 .5
 Fade 'Supply identity' $false 1 0 .5
 Fade 'Delta dissipativity' $false 1 0 .5
 Fade 'Dissipativity meaning' $false 2 0 .5
 $s=$d.Slides.Item(39);$seq=$s.TimeLine.MainSequence
 Fade 'PIE role' $false 1 0 .4
 Fade 'PIE decay' $false 2 .15 .5
 Fade 'Closed loop decay' $false 1 0 .5
 Fade 'Energy intuition' $false 2 .2 .5
 Fade 'Storage qualification' $false 2 .2 .5
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
 foreach($i in @(34,36,39)){$d.Slides.Item($i).Export((Join-Path $PSScriptRoot ('render-'+$i+'.png')),'PNG',1600,900)}
 Write-Output 'Animated original schematic reveal, plot zoom, and editable numeric gap values.'
}finally{$d.Close()}
