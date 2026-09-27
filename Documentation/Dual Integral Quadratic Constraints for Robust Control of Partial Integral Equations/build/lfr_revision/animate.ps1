$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$meta=Get-Content (Join-Path $PSScriptRoot 'animation.json') -Raw | ConvertFrom-Json
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try{
 $s=$d.Slides.Item(19);$seq=$s.TimeLine.MainSequence
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
 $nb=$meta.records.'Original neural schematic'.after1
 MoveShape 'Original neural schematic' ($nb[0]+$nb[2]/2) ($nb[1]+$nb[3]/2) 67 1 0 1.1
 MoveShape 'Moving nonlinearity S' ($meta.delta[0]-8) ($meta.delta[1]-5) 60 2 0 1.1
 MoveShape 'Moving nonlinearity G' ($meta.delta[0]+8) ($meta.delta[1]+5) 60 2 0 1.1
 Fade 'Original model equations' $true 2 .45 .4
 Fade 'Moving nonlinearity S' $true 2 .95 .3
 Fade 'Moving nonlinearity G' $true 2 .95 .3
 Fade 'Delta block' $false 2 .95 .4
 Fade 'Moving nominal dynamics' $false 2 .85 .4
 Fade 'Stage 1 caption' $false 2 .8 .3
 MoveShape 'Moving nominal dynamics' $meta.plant[0] $meta.plant[1] 25 1 0 1.1
 Fade 'Moving nominal dynamics' $true 2 .85 .35
 Fade 'G block' $false 2 .85 .4
 Fade 'Uncertainty connections' $false 2 1.05 .4
 Fade 'Control signal labels' $false 2 1.05 .4
 Fade 'Open control ports' $false 2 1.05 .4
 Fade 'Stage 1 caption' $true 2 0 .2
 Fade 'Stage 2 caption' $false 2 .3 .3
 Fade 'Controller K' $false 1 0 .6
 Fade 'Open control ports' $true 2 .3 .2
 Fade 'Controller connections' $false 2 .3 .6
 Fade 'Neural equivalence' $false 2 .6 .4
 Fade 'Stage 2 caption' $true 2 0 .2
 Fade 'Stage 3 caption' $false 2 .3 .3
 Fade 'ASML image' $false 1 0 .6
 foreach($nm in @('Canon image','ASML caption','Canon caption','Additional models heading','Industrial model arrow')){Fade $nm $false 2 .15 .6}
 Fade 'Stage 3 caption' $true 2 0 .3
 Fade 'Original neural schematic' $true 1 0 .5
 foreach($nm in @('ASML image','Canon image','ASML caption','Canon caption','Additional models heading','Industrial model arrow','Neural equivalence','Title 1')){Fade $nm $true 2 0 .5}
 foreach($nm in @('Delta block','G block','Uncertainty connections','Control signal labels','Controller K','Controller connections')){Fade $nm $true 2 .05 .05}
 Fade 'Complete LFR' $false 2 0 .05
 MoveShape 'Complete LFR' 360 223 112 2 .1 1.1
 Fade 'Final LFR title' $false 2 .8 .5
 $clicks=0;foreach($fx in $seq){if($fx.Timing.TriggerType -eq 1){$clicks++}}
 if($clicks -ne 5){throw 'Expected five click stages'}
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
 Write-Output ('Saved '+$seq.Count+' effects on five clicks.')
}finally{$d.Close()}
foreach($stage in 0..5){
 $p=$ppt.Presentations.Open((Join-Path $PSScriptRoot ('preview-'+$stage+'.pptx')),-1,0,0)
 try{$p.Slides.Item(19).Export((Join-Path $PSScriptRoot ('stage-'+$stage+'.png')),'PNG',1600,900)}finally{$p.Close()}
}
