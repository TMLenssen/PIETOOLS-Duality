$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
foreach($p in $ppt.Presentations){if($p.Name -eq 'Sector IQC - Editable.pptx' -and $p.Saved -ne -1){throw 'Sector IQC presentation has unsaved changes.'}}
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try{
 if($d.Slides.Count -ne 4){throw 'Expected four slides'}
 foreach($s in $d.Slides){$s.Export((Join-Path $PSScriptRoot ('slide-'+$s.SlideIndex+'.png')),'PNG',1600,900)}
 $d.SaveCopyAs((Join-Path $PSScriptRoot 'Sector IQC - Editable.pptx'),24)
 $d.SaveAs((Join-Path $PSScriptRoot 'Sector IQC - Editable.pdf'),32)
 Write-Output 'PowerPoint verified four slides and exported the updated PDF.'
}finally{$d.Close()}
