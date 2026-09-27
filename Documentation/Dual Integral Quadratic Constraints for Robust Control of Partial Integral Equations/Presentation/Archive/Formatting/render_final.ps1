param([string]$FileName='Dual IQC - Formatted.pptx',[string]$PreviewDirectory='final_preview')
$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$file=Join-Path (Split-Path $PSScriptRoot) $FileName
$out=Join-Path $PSScriptRoot $PreviewDirectory
New-Item -ItemType Directory -Path $out -Force | Out-Null
$deck=$ppt.Presentations.Open($file,-1,0,-1)
try {
    foreach($slide in $deck.Slides){$slide.Export((Join-Path $out ('slide-{0:D2}.png' -f $slide.SlideIndex)),'PNG',1280,720)}
    Write-Output ('Rendered '+$deck.Slides.Count+' slides.')
} finally {$deck.Close()}
