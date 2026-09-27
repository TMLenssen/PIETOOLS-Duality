$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'staged.pptx'),0,0,0)
try {
 $s=$d.Slides.Item(43);$clicks=0
 foreach($e in $s.TimeLine.MainSequence){if($e.Timing.TriggerType -eq 1){$clicks++}}
 if($clicks -ne 5){throw ('Expected 5 clicks, got '+$clicks)}
 Write-Output ('Verified '+$clicks+' click stages and Morph effect '+$s.SlideShowTransition.EntryEffect)
 $d.SaveAs((Join-Path $PSScriptRoot 'animated.pptx'),24)
} finally {$d.Close()}
