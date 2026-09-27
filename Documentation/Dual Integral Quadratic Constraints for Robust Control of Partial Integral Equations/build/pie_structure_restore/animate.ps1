$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try{
 $s=$d.Slides.Item(20);$seq=$s.TimeLine.MainSequence
 function FindShape([string]$name){
  $ids=@{'Rectangle: Rounded Corners 10'=11;'Rectangle: Rounded Corners 12'=13;'Arrow: Left-Right 13'=14;'TextBox 14'=15;'Content Placeholder 2'=3}
  foreach($sh in $s.Shapes){if($sh.Name -eq $name -or ($ids.ContainsKey($name) -and $sh.Id -eq $ids[$name])){return $sh}}
  throw ('Missing '+$name)
 }
 function Fade([string]$name,[bool]$exit,[int]$trigger,[double]$delay,[double]$duration){
  $e=$seq.AddEffect((FindShape $name),10,0,$trigger);$e.Exit=[int](-[int]$exit);$e.Timing.Duration=$duration;$e.Timing.TriggerDelayTime=$delay
 }
 $sh=FindShape 'Extracted PDE block';$dx=(359.5-$sh.Left-$sh.Width/2)/720;$dy=(117-$sh.Top-$sh.Height/2)/405
 $e=$seq.AddEffect($sh,0,0,1);$e.Timing.Duration=1.0
 $motion=$e.Behaviors.Add(1);$motion.MotionEffect.Path=('M 0 0 L '+$dx.ToString('0.########',[Globalization.CultureInfo]::InvariantCulture)+' '+$dy.ToString('0.########',[Globalization.CultureInfo]::InvariantCulture)+' E')
 $sc=$e.Behaviors.Add(3);$sc.ScaleEffect.FromX=100;$sc.ScaleEffect.FromY=100;$sc.ScaleEffect.ToX=60;$sc.ScaleEffect.ToY=60
 $e.Timing.SmoothStart=-1;$e.Timing.SmoothEnd=-1
 Fade 'Surrounding LFR' $true 2 0 .55
 Fade 'Extracted PDE block' $true 2 .85 .25
 Fade 'Rectangle: Rounded Corners 10' $false 2 .85 .25
 Fade 'Content Placeholder 2' $false 2 .65 .4
 foreach($nm in @('Rectangle: Rounded Corners 12','Arrow: Left-Right 13','TextBox 14')){Fade $nm $false 2 .95 .4}
 $d.Slides.Item(26).SlideShowTransition.EntryEffect=1793
 $d.Slides.Item(26).SlideShowTransition.Duration=.8
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
 Write-Output 'Created one-click PDE extraction and a soft transition into the pillar panels.'
}finally{$d.Close()}
