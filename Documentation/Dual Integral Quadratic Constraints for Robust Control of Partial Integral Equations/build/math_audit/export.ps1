$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
foreach($p in $ppt.Presentations){if($p.FullName -like '*Contstraints*' -and $p.Saved -ne -1){throw 'Source has unsaved edits.'}}
$inputFile=Join-Path $PSScriptRoot 'source.pptx'
if($args.Count -gt 0){$inputFile=Join-Path $PSScriptRoot $args[0]}
$deck=$ppt.Presentations.Open($inputFile,-1,0,0)
try{
 $prefix=if($args.Count -gt 0){'after'}else{'before'}
 foreach($s in $deck.Slides){$s.Export((Join-Path $PSScriptRoot ($prefix+'-'+$s.SlideIndex+'.png')),'PNG',1600,900)}
 Write-Output ('Exported '+$deck.Slides.Count+' slides.')
}finally{$deck.Close()}
