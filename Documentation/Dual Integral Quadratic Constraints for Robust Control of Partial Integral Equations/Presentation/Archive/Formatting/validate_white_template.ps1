$ErrorActionPreference='Stop'
Add-Type -AssemblyName WindowsBase
Add-Type -Path 'C:\Program Files\Microsoft Office\root\vfs\ProgramFilesX86\Microsoft Office\Office16\DCF\DocumentFormat.OpenXml.dll'
$validator=New-Object DocumentFormat.OpenXml.Validation.OpenXmlValidator
$dir=Join-Path $PSScriptRoot 'template_fix'
foreach($name in @('original.pptx','Dual Integral Quadratic Contstraints for Robust Control of Partial Integral Equations.pptx','TUe - Clean White.potx')) {
    $path=Join-Path $dir $name
    $doc=[DocumentFormat.OpenXml.Packaging.PresentationDocument]::Open($path,$false)
    try {
        $errors=@($validator.Validate($doc))
        $rows=@($errors | ForEach-Object { [pscustomobject]@{Part=$_.Part.Uri.ToString();Path=$_.Path.XPath;Description=$_.Description} })
        $rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath ($path+'.validation.json')
        Write-Output ($name+': '+$errors.Count+' validation errors')
        $rows | Select-Object -First 12 | Format-List
    } finally {$doc.Dispose()}
}
