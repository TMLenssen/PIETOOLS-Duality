$ErrorActionPreference='Stop'
$dir=Join-Path $PSScriptRoot 'video_fix'
$report=Get-Content -LiteralPath (Join-Path $dir 'report.json') -Raw | ConvertFrom-Json
Copy-Item -LiteralPath $report.output -Destination (Join-Path $dir 'after.pptx') -Force
$ppt=New-Object -ComObject PowerPoint.Application
foreach($case in @('before','after')) {
    $path=Join-Path $dir ($case+'.pptx')
    $deck=$ppt.Presentations.Open($path,-1,0,0)
    try {
        $slide=$deck.Slides.Item(2)
        $slide.Export((Join-Path $dir ($case+'.png')),'PNG',1600,900)
        foreach($s in $slide.Shapes){if($s.Type -eq 16){Write-Output ($case+': '+$s.Name+' video duration='+$s.MediaFormat.Length+'ms')}}
    } finally {$deck.Close()}
}
