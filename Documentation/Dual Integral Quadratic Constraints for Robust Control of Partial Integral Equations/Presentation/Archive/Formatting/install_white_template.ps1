$ErrorActionPreference='Stop'
$staging=Join-Path $PSScriptRoot 'template_fix'
$destination='C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation'
$name='Dual Integral Quadratic Contstraints for Robust Control of Partial Integral Equations.pptx'
$target=Join-Path $destination $name
$report=Get-Content -LiteralPath (Join-Path $staging 'validation.json') -Raw | ConvertFrom-Json
$actual=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
if($actual -ne $report.source_sha256){throw 'The presentation changed since the working copy was created. Refresh the repair before installing.'}
# Do not replace an open presentation: an in-memory copy could overwrite the repair.
$lock=Join-Path $destination ('~$'+$name)
$canReplace=$false
try {
    $probe=[IO.File]::Open($target,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $probe.Dispose()
    $canReplace=$true
} catch [IO.IOException] {
    Write-Output 'The original presentation is locked; saving the corrected deck alongside it.'
}
if(Test-Path -LiteralPath $lock){
    $canReplace=$false
    Write-Output 'PowerPoint has a lock file for the original; preserving the open presentation.'
}
if($canReplace){
    $backup=Join-Path $destination (($name -replace '\.pptx$','')+' - before template fix '+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.pptx')
    Copy-Item -LiteralPath $target -Destination $backup
    Copy-Item -LiteralPath (Join-Path $staging $name) -Destination $target -Force
    Write-Output ('UPDATED: '+$target)
    Write-Output ('BACKUP: '+$backup)
} else {
    $target=Join-Path $destination (($name -replace '\.pptx$','')+' - Clean White.pptx')
    if(Test-Path -LiteralPath $target){throw ('A corrected copy already exists; do not overwrite it: '+$target)}
    Copy-Item -LiteralPath (Join-Path $staging $name) -Destination $target
    Write-Output ('CORRECTED COPY: '+$target)
}
$templateTarget=Join-Path $destination 'TUe - Clean White.potx'
if(Test-Path -LiteralPath $templateTarget){throw 'A template with this name already exists. The repaired presentation was saved, but the existing template has not been overwritten.'}
Copy-Item -LiteralPath (Join-Path $staging 'TUe - Clean White.potx') -Destination $templateTarget
if((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath (Join-Path $staging $name)).Hash){throw 'Presentation copy verification failed.'}
if((Get-FileHash -LiteralPath $templateTarget).Hash -ne (Get-FileHash -LiteralPath (Join-Path $staging 'TUe - Clean White.potx')).Hash){throw 'Template copy verification failed.'}
Write-Output ('TEMPLATE: '+$templateTarget)
