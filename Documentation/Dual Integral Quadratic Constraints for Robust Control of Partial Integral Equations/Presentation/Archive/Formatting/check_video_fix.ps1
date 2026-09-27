$ErrorActionPreference='Stop'
$dir=Join-Path $PSScriptRoot 'video_fix'
$report=Get-Content -LiteralPath (Join-Path $dir 'report.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName WindowsBase
Add-Type -Path 'C:\Program Files\Microsoft Office\root\vfs\ProgramFilesX86\Microsoft Office\Office16\DCF\DocumentFormat.OpenXml.dll'
$validator=New-Object DocumentFormat.OpenXml.Validation.OpenXmlValidator
foreach($path in @($report.output)+@($report.templates | ForEach-Object {$_.output})) {
    $doc=[DocumentFormat.OpenXml.Packaging.PresentationDocument]::Open($path,$false)
    try {
        $errors=@($validator.Validate($doc))
        if($errors.Count){$errors | Format-List;throw 'OpenXML validation failed'}
        Write-Output ('Validated: '+$path)
    } finally {$doc.Dispose()}
}
