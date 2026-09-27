$ErrorActionPreference='Stop'
$dir=Join-Path $PSScriptRoot 'video_fix'
$r=Get-Content -LiteralPath (Join-Path $dir 'report.json') -Raw | ConvertFrom-Json
$jobs=@([pscustomobject]@{source=$r.source;output=$r.output;sha256=$r.source_sha256})+@($r.templates)
foreach($j in $jobs){
    if((Get-FileHash -LiteralPath $j.source -Algorithm SHA256).Hash -ne $j.sha256){throw ('File changed since repair: '+$j.source)}
    $lock=Join-Path (Split-Path $j.source) ('~$'+(Split-Path $j.source -Leaf))
    if(Test-Path -LiteralPath $lock){throw ('Please close the open presentation before replacing it: '+$j.source)}
    $probe=[IO.File]::Open($j.source,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $probe.Dispose()
}
foreach($j in $jobs){
    Copy-Item -LiteralPath $j.output -Destination $j.source -Force
    if((Get-FileHash -LiteralPath $j.source).Hash -ne (Get-FileHash -LiteralPath $j.output).Hash){throw 'Copy verification failed'}
    Write-Output ('REPAIRED: '+$j.source)
}
