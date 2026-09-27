$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try{
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
 $s=$d.Slides.Item(20);$seq=$s.TimeLine.MainSequence
 $sh=FindShape '!!PDE block';$scale=7000/$sh.Width
 MoveShape '!!PDE block' 358 119 $scale 1 0 1.05
 Fade 'Surrounding LFR' $true 2 0 .6
 Fade 'Property list' $false 2 .5 .4
 foreach($nm in @('!!PIE block','Equivalence arrow','Exact label')){Fade $nm $false 2 .7 .45}
 foreach($nm in @('PDE dynamics','!!PIE time terms','!!PIE spatial terms','!!PIE equals terms')){Fade $nm $false 2 1 .5}
 $s=$d.Slides.Item(21);$seq=$s.TimeLine.MainSequence
 # Entry animation: concrete derivative and state terms become T and A.
 MoveShape '!!PIE time terms' 365 222 15 2 .15 1.15
 MoveShape '!!PIE spatial terms' 465 222 15 2 .15 1.15
 Fade 'PDE dynamics leaving' $true 2 0 .5
 Fade '!!PIE equals terms' $true 2 0 .4
 Fade '!!PIE time terms' $true 2 1.08 .3
 Fade '!!PIE spatial terms' $true 2 1.08 .3
 Fade 'PIE dynamics' $false 2 1.12 .5
 Fade 'PIE output' $false 2 1.5 .4
 Fade 'PI operator class' $false 2 1.7 .4
 if($d.Slides.Item(25).SlideShowTransition.EntryEffect -ne 3954){throw 'Pillar transition is not Morph'}
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
 Write-Output 'Animated PDE extraction and dynamics-to-operators; confirmed Morph into the pillars.'
}finally{$d.Close()}
