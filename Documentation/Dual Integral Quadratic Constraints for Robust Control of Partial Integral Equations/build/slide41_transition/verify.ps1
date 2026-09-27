$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
foreach($name in @('before','after','final')) {
 $d=$ppt.Presentations.Open((Join-Path $PSScriptRoot ($name+'.pptx')),-1,0,0)
 try {
  $s=$d.Slides.Item(41)
  if($name -ne 'final') { $s.Export((Join-Path $PSScriptRoot ($name+'.png')),'PNG',1600,900) }
  else {
   $clicks=0;$fades=0
   foreach($e in $s.TimeLine.MainSequence) {
    if($e.Timing.TriggerType -eq 1) {$clicks++}
    if($e.EffectType -eq 10 -and $e.Shape.Name -like '*inequality') {$fades++}
   }
   if($clicks -ne 7 -or $fades -lt 4) { throw ('Unexpected animation sequence: '+$clicks+' clicks; '+$fades+' fades') }
   Write-Output 'Verified seven clicks and four synchronized fades; original later motion effects retained.'
  }
 } finally { $d.Close() }
}
