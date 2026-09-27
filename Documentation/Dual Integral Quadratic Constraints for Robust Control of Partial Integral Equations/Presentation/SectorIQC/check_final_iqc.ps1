$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dir=Join-Path $workspace 'build\iqc_final'
$report=Get-Content -LiteralPath (Join-Path $dir 'report.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName WindowsBase
Add-Type -Path 'C:\Program Files\Microsoft Office\root\vfs\ProgramFilesX86\Microsoft Office\Office16\DCF\DocumentFormat.OpenXml.dll'
$document=[DocumentFormat.OpenXml.Packaging.PresentationDocument]::Open($report.output,$false)
try {
    $validator=New-Object DocumentFormat.OpenXml.Validation.OpenXmlValidator([DocumentFormat.OpenXml.FileFormatVersions]::Office2013)
    $errors=@($validator.Validate($document))
    if($errors.Count -gt 0){$errors | Select-Object -First 8 Description,Path | Format-List;throw 'OpenXML validation failed'}
} finally {$document.Dispose()}
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open($report.output,-1,0,0)
try {foreach($i in $report.slides){$deck.Slides.Item($i).Export((Join-Path $dir "slide-$i.png"),'PNG',1920,1080)}} finally {$deck.Close()}
Write-Output 'All three simulation slides rendered; OpenXML validation passed.'
