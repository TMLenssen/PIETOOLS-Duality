$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'Simulation\STN_GPe_Zames_Falb'
$destination='C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\Zames-Falb IQC - Simulation'
$names=@('STN-GPe Zames-Falb simulation.html','Zames-Falb - Editable.pptx','Zames-Falb - Editable.pdf','Zames-Falb integral.mp4','Zames-Falb rate.mp4','Zames-Falb integral.png','Zames-Falb rate.png','results.json','README.md','supply_history.csv','stn_gpe_zames_falb_data.npz')
foreach($name in $names){if(-not(Test-Path -LiteralPath (Join-Path $source $name))){throw "Missing output: $name"}}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach($name in $names){
    $from=Join-Path $source $name
    $to=Join-Path $destination $name
    if(Test-Path -LiteralPath $to){
        if((Get-FileHash -LiteralPath $to).Hash -eq (Get-FileHash -LiteralPath $from).Hash){continue}
        throw "An existing different output needs to be archived before replacing it: $to"
    }
    Copy-Item -LiteralPath $from -Destination $to
    if((Get-FileHash -LiteralPath $to).Hash -ne (Get-FileHash -LiteralPath $from).Hash){throw "Copy verification failed: $name"}
}
Write-Output "Installed and verified $($names.Count) files in $destination"
