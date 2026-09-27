$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$meta=Get-Content (Join-Path $PSScriptRoot 'source.json') -Raw | ConvertFrom-Json
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 if($d.Slides.Count -ne $meta.slides){throw 'Slide count changed'}
 $s=$d.Slides.Item(43); $clicks=0
 foreach($e in $s.TimeLine.MainSequence){if($e.Timing.TriggerType -eq 1){$clicks++}}
 if($clicks -ne 2){throw ('Expected two clicks, found '+$clicks)}
 if($s.TimeLine.MainSequence.Count -ne 10){throw 'Incorrect effect count'}
 Write-Output 'Verified slide count and two click-triggered stages.'
} finally {$d.Close()}
foreach($stage in @('initial','comparison','result')){
 $d=$ppt.Presentations.Open((Join-Path $PSScriptRoot ($stage+'.pptx')),-1,0,0)
 try {$d.Slides.Item(43).Export((Join-Path $PSScriptRoot ($stage+'.png')),'PNG',1600,900)} finally {$d.Close()}
}
