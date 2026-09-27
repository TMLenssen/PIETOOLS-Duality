$ErrorActionPreference='Stop'
$dir=Join-Path $PSScriptRoot 'lfr_library'
$path=Join-Path $dir 'LFR - Editable.pptx'
Add-Type -AssemblyName WindowsBase
Add-Type -Path 'C:\Program Files\Microsoft Office\root\vfs\ProgramFilesX86\Microsoft Office\Office16\DCF\DocumentFormat.OpenXml.dll'
$validator=New-Object DocumentFormat.OpenXml.Validation.OpenXmlValidator
$doc=[DocumentFormat.OpenXml.Packaging.PresentationDocument]::Open($path,$false)
try {
    $errors=@($validator.Validate($doc))
    if($errors.Count){$errors | Select-Object -First 8 | ForEach-Object {Write-Output ($_.Description+' '+$_.Path.XPath)};throw 'Validation failed'}
    Write-Output 'Open XML validation passed.'
} finally {$doc.Dispose()}
$out=Join-Path $dir 'preview'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open($path,-1,0,0)
try {
    $index=Get-Content -LiteralPath (Join-Path $dir 'index.json') -Raw | ConvertFrom-Json
    $vectors=Join-Path $dir 'native_exports'
    New-Item -ItemType Directory -Force -Path $vectors | Out-Null
    foreach($row in $index){$deck.Slides.Item([int]$row.slide).Shapes.Item(2).Export((Join-Path $vectors ($row.asset+'.svg')),6)}
    $deck.Slides.Item(16).Shapes.Item(2).Export((Join-Path $vectors '16-pde-to-pie-conversion.svg'),6)
    foreach($slide in $deck.Slides){$slide.Export((Join-Path $out ('slide-{0:D2}.png' -f $slide.SlideIndex)),'PNG',1280,720)}
    $deck.SaveAs((Join-Path $dir 'LFR - Editable.pdf'),32)
    Write-Output ('Rendered '+$deck.Slides.Count+' slides.')
} finally {$deck.Close()}
