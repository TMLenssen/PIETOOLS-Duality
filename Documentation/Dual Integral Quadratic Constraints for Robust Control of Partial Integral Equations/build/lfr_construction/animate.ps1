$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try{
 $s=$d.Slides.Item(19);$seq=$s.TimeLine.MainSequence
 for($i=$seq.Count;$i -ge 1;$i--){$seq.Item($i).Delete()}
 function FindShape([string]$name){foreach($sh in $s.Shapes){if($sh.Name -eq $name){return $sh}};throw ('Missing '+$name)}
 function Fade([string]$name,[bool]$exit,[int]$trigger,[double]$delay,[double]$duration){
  $e=$seq.AddEffect((FindShape $name),10,0,$trigger);$e.Exit=[int](-[int]$exit);$e.Timing.Duration=$duration;$e.Timing.TriggerDelayTime=$delay
 }
 function MoveShape([string]$name,[double]$x,[double]$y,[double]$scale,[int]$trigger,[double]$delay,[double]$duration){
  $sh=FindShape $name;$dx=($x-$sh.Left-$sh.Width/2)/720;$dy=($y-$sh.Top-$sh.Height/2)/405
  $e=$seq.AddEffect($sh,0,0,$trigger);$e.Timing.Duration=$duration;$e.Timing.TriggerDelayTime=$delay
  $motion=$e.Behaviors.Add(1)
  $motion.MotionEffect.Path=('M 0 0 L '+$dx.ToString('0.########',[Globalization.CultureInfo]::InvariantCulture)+' '+$dy.ToString('0.########',[Globalization.CultureInfo]::InvariantCulture)+' E')
  if($scale -ne 100){$sc=$e.Behaviors.Add(3);$sc.ScaleEffect.FromX=100;$sc.ScaleEffect.FromY=100;$sc.ScaleEffect.ToX=$scale;$sc.ScaleEffect.ToY=$scale}
  $e.Timing.SmoothStart=-1;$e.Timing.SmoothEnd=-1
 }
 # Click 1: collect the two nonlinear activation terms in Delta.
 MoveShape 'Original neural schematic' 181 172 64 1 0 1.0
 MoveShape 'Moving nonlinearity S' 527 120 70 2 0 1.0
 MoveShape 'Moving nonlinearity G' 549 131 70 2 0 1.0
 Fade 'Original model equations' $true 2 .45 .35
 Fade 'Moving nonlinearity S' $true 2 .9 .3
 Fade 'Moving nonlinearity G' $true 2 .9 .3
 Fade 'Delta block' $false 2 .88 .4
 Fade 'Moving nominal dynamics' $false 2 .8 .4
 Fade 'Stage 1 caption' $false 2 .7 .3
 # Click 2: all remaining linear dynamics and delays form P.
 MoveShape 'Moving nominal dynamics' 538 236 25 1 0 1.0
 Fade 'Moving nominal dynamics' $true 2 .75 .35
 Fade 'P block' $false 2 .8 .4
 Fade 'LFR signal connections' $false 2 1.05 .45
 Fade 'Stage 1 caption' $true 2 0 .2
 Fade 'Stage 2 caption' $false 2 .3 .3
 # Click 3: attach K to the exposed measurement and actuation ports.
 Fade 'Controller K' $false 1 0 .65
 Fade 'Controller connections' $false 2 .35 .7
 Fade 'Stage 2 caption' $true 2 0 .2
 Fade 'Stage 3 caption' $false 2 .3 .3
 # Click 4: close the matching schematic and show exact equivalence.
 Fade 'Original neural schematic' $true 1 0 .2
 Fade 'Equivalent original schematic' $false 2 0 .2
 Fade 'Schematic controller connection' $false 2 .2 .65
 Fade 'Equivalence symbol' $false 2 .65 .45
 Fade 'Equivalent schematic heading' $false 2 .5 .35
 Fade 'LFR heading' $false 2 .5 .35
 Fade 'Stage 3 caption' $true 2 0 .2
 Fade 'Stage 4 caption' $false 2 .65 .4
 $clicks=0;foreach($fx in $seq){if($fx.Timing.TriggerType -eq 1){$clicks++}}
 if($clicks -ne 4){throw ('Expected four click stages, found '+$clicks)}
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
 Write-Output ('Slide 19: '+$seq.Count+' effects, '+$clicks+' clicks.')
}finally{$d.Close()}
foreach($stage in 0..4){
 $p=$ppt.Presentations.Open((Join-Path $PSScriptRoot ('preview-'+$stage+'.pptx')),-1,0,0)
 try{$p.Slides.Item(19).Export((Join-Path $PSScriptRoot ('stage-'+$stage+'.png')),'PNG',1600,900)}finally{$p.Close()}
}
