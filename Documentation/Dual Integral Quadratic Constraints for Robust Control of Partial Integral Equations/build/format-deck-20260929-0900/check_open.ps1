$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'attach.ps1')
foreach($d in $ppt.Presentations){Write-Output ($d.FullName+' | saved='+$d.Saved+' | slides='+$d.Slides.Count)}
