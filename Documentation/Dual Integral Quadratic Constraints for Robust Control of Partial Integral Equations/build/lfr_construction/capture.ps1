$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
foreach($p in $ppt.Presentations){if($p.Name -like 'Dual Integral Quadratic Contstraints*' -and $p.Saved -ne -1){throw 'Presentation has unsaved changes.'}}
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'source.pptx'),-1,0,0)
try{$d.Slides.Item(19).Export((Join-Path $PSScriptRoot 'before.png'),'PNG',1600,900)}finally{$d.Close()}
# Read locally installed Office enum values; avoid guessing animation constants.
$types=[AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {try{$_.GetTypes()}catch{}} | Where-Object {$_.Name -match 'MsoAnimEffect|MsoAnimType|MsoAnimTriggerType'}
foreach($t in $types){Write-Output $t.FullName;[Enum]::GetNames($t) | Where-Object {$_ -match 'Custom|Fade|Appear|Motion|Scale|Grow|Wipe|WithPrevious|OnPageClick'} | ForEach-Object {Write-Output ($_+' '+[int][Enum]::Parse($t,$_))}}
