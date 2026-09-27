$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out=Join-Path $workspace 'build\simple_deck'
$r=Get-Content -LiteralPath (Join-Path $out 'report.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName WindowsBase
Add-Type -Path 'C:\Program Files\Microsoft Office\root\vfs\ProgramFilesX86\Microsoft Office\Office16\DCF\DocumentFormat.OpenXml.dll'
$d=[DocumentFormat.OpenXml.Packaging.PresentationDocument]::Open($r.output,$false)
try {
    $validator=New-Object DocumentFormat.OpenXml.Validation.OpenXmlValidator([DocumentFormat.OpenXml.FileFormatVersions]::Office2013)
    $errors=@($validator.Validate($d))
    if($errors.Count -gt 0){foreach($e in $errors | Select-Object -First 8){Write-Output "$($e.Part.Uri) $($e.Path.XPath) $($e.Description)"};throw 'OpenXML validation failed'}
} finally {$d.Dispose()}
$ppt=New-Object -ComObject PowerPoint.Application
foreach($entry in @(@{path=(Join-Path $out 'source.pptx');prefix='before'},@{path=$r.output;prefix='after'})){
    $deck=$ppt.Presentations.Open($entry.path,-1,0,0)
    try {
        foreach($i in @(1,2,3,4,13,26,27,28,29,32,39)){$deck.Slides.Item($i).Export((Join-Path $out "$($entry.prefix)-$i.png"),'PNG',1920,1080)}
        if($entry.prefix -eq 'after'){
            foreach($i in 1..$deck.Slides.Count){$deck.Slides.Item($i).Export((Join-Path $out "overview-$i.png"),'PNG',1280,720)}
        }
    } finally {$deck.Close()}
}
Write-Output 'Rendered all simplified slides and baseline comparisons; OpenXML validation passed.'
