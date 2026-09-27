$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out=Join-Path $workspace 'build\spatial_labels'
$r=Get-Content -LiteralPath (Join-Path $out 'report.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName WindowsBase
Add-Type -Path 'C:\Program Files\Microsoft Office\root\vfs\ProgramFilesX86\Microsoft Office\Office16\DCF\DocumentFormat.OpenXml.dll'
$d=[DocumentFormat.OpenXml.Packaging.PresentationDocument]::Open($r.output,$false)
try {
    $validator=New-Object DocumentFormat.OpenXml.Validation.OpenXmlValidator([DocumentFormat.OpenXml.FileFormatVersions]::Office2013)
    $errors=@($validator.Validate($d))
    if($errors.Count -gt 0){foreach($e in $errors | Select-Object -First 8){Write-Output "$($e.Part.Uri) $($e.Description)"};throw 'OpenXML validation failed'}
} finally {$d.Dispose()}
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open($r.output,-1,0,0)
try {foreach($i in @(2,4)){$deck.Slides.Item($i).Export((Join-Path $out "slide-$i.png"),'PNG',1920,1080)}} finally {$deck.Close()}
Write-Output 'Slides 2 and 4 rendered; OpenXML validation passed.'
