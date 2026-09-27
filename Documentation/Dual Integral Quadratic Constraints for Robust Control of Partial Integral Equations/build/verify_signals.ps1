$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'slides33_35_signals'
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open((Join-Path $out 'final.pptx'),-1,0,0)
try {
 if($deck.Slides.Count -ne 45){throw 'Unexpected slide count.'}
 foreach($n in @(33,34,35)){
  $slide=$deck.Slides.Item($n);$clicks=0
  foreach($fx in $slide.TimeLine.MainSequence){if($fx.Timing.TriggerType -eq 1){$clicks++}}
  if($clicks -ne 3){throw ('Unexpected click sequence on slide '+$n)}
  $slide.Export((Join-Path $out ('final-'+$n+'.png')),'PNG',1600,900)
  Write-Output ('Verified slide '+$n+': three click stages.')
 }
}finally{$deck.Close()}


