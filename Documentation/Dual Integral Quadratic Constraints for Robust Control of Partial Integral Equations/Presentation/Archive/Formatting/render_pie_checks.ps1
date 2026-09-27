$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
foreach($stage in 1..4){
    $deck=$ppt.Presentations.Open((Join-Path $PSScriptRoot ('pie-check-'+$stage+'.pptx')),-1,0,-1)
    try{$deck.Slides.Item(4).Export((Join-Path $PSScriptRoot ('pie-check-'+$stage+'.png')),'PNG',1280,720)}finally{$deck.Close()}
}
Write-Output 'Rendered four individual PIE states.'
