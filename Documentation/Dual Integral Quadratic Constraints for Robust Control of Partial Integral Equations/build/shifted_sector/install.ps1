$ErrorActionPreference='Stop'
$meta=Get-Content (Join-Path $PSScriptRoot 'source.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath $meta.source).Hash -ne $meta.hash){throw 'Source deck changed during editing; refusing to overwrite newer edits.'}
$probe=[IO.File]::Open($meta.source,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$probe.Dispose()
$folder=Split-Path $meta.source -Parent
$archive=Join-Path $folder ('Archive/Before shifted sigmoid sector '+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $archive -Force | Out-Null
foreach($name in @('Sector IQC - Editable.pptx','Sector IQC - Editable.pdf')){
 $target=Join-Path $folder $name
 if(Test-Path -LiteralPath $target){Copy-Item -LiteralPath $target -Destination $archive}
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $target -Force
 if((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $name)).Hash){throw 'Installed artifact differs from verified artifact'}
}
[pscustomobject]@{presentation=$meta.source;pdf=(Join-Path $folder 'Sector IQC - Editable.pdf');archive=$archive;slides=4} | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot 'installed.json') -Encoding UTF8
Write-Output ('Saved shifted-sigmoid sector PowerPoint and PDF. Backup: '+$archive)
