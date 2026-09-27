$ErrorActionPreference = 'Stop'
$source = 'C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\Dual Integral Quadratic Constraints for Robust Control of Partial Integral Equations.pptx'
$outDir = Join-Path $PSScriptRoot 'original'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$ppt = New-Object -ComObject PowerPoint.Application
$deck = $ppt.Presentations.Open($source, -1, 0, -1)
try {
    $result = @()
    foreach ($slide in $deck.Slides) {
        $slide.Export((Join-Path $outDir ('slide-{0:D2}.png' -f $slide.SlideIndex)), 'PNG', 1600, 900)
        $shapes = @()
        foreach ($shape in $slide.Shapes) {
            $text = ''
            if ($shape.HasTextFrame -eq -1 -and $shape.TextFrame.HasText -eq -1) { $text = $shape.TextFrame.TextRange.Text }
            $shapes += [pscustomobject]@{Id=$shape.Id;Name=$shape.Name;Type=$shape.Type;Left=$shape.Left;Top=$shape.Top;Width=$shape.Width;Height=$shape.Height;Text=$text}
        }
        $effects = @()
        foreach ($effect in $slide.TimeLine.MainSequence) {
            $effects += [pscustomobject]@{ShapeId=$effect.Shape.Id;ShapeName=$effect.Shape.Name;EffectType=$effect.EffectType;Exit=$effect.Exit;Trigger=$effect.Timing.TriggerType;Duration=$effect.Timing.Duration;Delay=$effect.Timing.TriggerDelayTime}
        }
        $result += [pscustomobject]@{Index=$slide.SlideIndex;Shapes=$shapes;Effects=$effects}
    }
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'inspection.json') -Encoding UTF8
    Write-Output ('Exported {0} slides to {1}' -f $deck.Slides.Count,$outDir)
} finally {
    $deck.Close()
}
