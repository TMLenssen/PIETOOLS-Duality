$ErrorActionPreference='Stop'
$outDir=Join-Path $PSScriptRoot 'formatted'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$output=Join-Path (Split-Path $PSScriptRoot) 'Dual IQC - Clean copy.pptx'
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'expanded.pptx'),0,0,-1)
$dark=0x292525
$gray=0x827B74
$red=0x1919C7
function Shape($slide,[int]$id) { foreach($s in $slide.Shapes) { if($s.Id -eq $id) { return $s } }; return $null }
function Box($s,$x,$y,$w,$h) { $s.LockAspectRatio=0; $s.Left=$x; $s.Top=$y; $s.Width=$w; $s.Height=$h }
function Txt($s,$size,$bold=0,$color=$dark,$align=1) {
    if(!$s){return}
    $s.Fill.Visible=0; $s.Line.Visible=0
    $s.TextFrame.AutoSize=0; $s.TextFrame.WordWrap=-1
    $s.TextFrame.MarginLeft=0; $s.TextFrame.MarginRight=0; $s.TextFrame.MarginTop=0; $s.TextFrame.MarginBottom=0
    $s.TextFrame.VerticalAnchor=1
    $font=$s.TextFrame.TextRange.Font
    $font.Bold=[int]$bold
    $font.Size=[single]$size
    $font.Color.RGB=[int]$color
    $font.Name='Aptos'
    $s.TextFrame.TextRange.ParagraphFormat.Alignment=$align
    $s.TextFrame.TextRange.ParagraphFormat.SpaceBefore=0
    $s.TextFrame.TextRange.ParagraphFormat.SpaceAfter=0
}
function MathBox($s,$x,$y,$w,$h,$size) {
    Box $s $x $y $w $h
    $s.TextFrame.AutoSize=0; $s.TextFrame.WordWrap=0
    $s.TextFrame.MarginLeft=0; $s.TextFrame.MarginRight=0; $s.TextFrame.MarginTop=0; $s.TextFrame.MarginBottom=0
    $s.TextFrame.TextRange.Font.Size=$size
}
function Fit($s,$x,$y,$w,$h) {
    $ratio=$s.Width/$s.Height
    if($w/$h -gt $ratio){$nw=$h*$ratio;$nh=$h}else{$nw=$w;$nh=$w/$ratio}
    Box $s ($x+($w-$nw)/2) ($y+($h-$nh)/2) $nw $nh
}
function ClearAnimations($slide) {
    for($i=$slide.TimeLine.MainSequence.Count;$i -ge 1;$i--){$slide.TimeLine.MainSequence.Item($i).Delete()}
}
function Keep($slide,$ids) {
    for($i=$slide.Shapes.Count;$i -ge 1;$i--){$s=$slide.Shapes.Item($i);if($ids -notcontains [int]$s.Id){$s.Delete()}}
}
function Base($slide,$title=$false) {
    $slide.DisplayMasterShapes=0
    $slide.FollowMasterBackground=0
    $slide.Background.Fill.Solid();$slide.Background.Fill.ForeColor.RGB=0xFFFFFF
    $slide.SlideShowTransition.EntryEffect=0;$slide.SlideShowTransition.AdvanceOnTime=0;$slide.SlideShowTransition.AdvanceOnClick=-1
    foreach($s in $slide.Shapes) {
        if($s.HasTextFrame -eq -1 -and $s.TextFrame.HasText -eq -1) {
            if($s.TextFrame.TextRange.Text -eq 'Msc Defence T.M. Lenssen') {Box $s 36 384 400 12;Txt $s 8 0 $gray}
            elseif($s.Name -like 'Slide Number*') {Box $s 620 384 28 12;Txt $s 8 0 $gray 3}
        }
    }
    if(!$title) { $logo=$slide.Shapes.AddPicture((Join-Path $PSScriptRoot 'media\image1.png'),0,-1,666,380,36,18);$logo.Name='Original TUe logo' }
}
try {
    $deck.SaveAs($output)
    # Native slide XML was duplicated before opening, preserving every original ID.
    $groups=@{}
    $mapping=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'stage_map.json') -Raw | ConvertFrom-Json
    foreach($row in $mapping) {
        $n=[int]$row.original
        if(!$groups.ContainsKey($n)){$groups[$n]=@()}
        $groups[$n]+=,$deck.Slides.Item([int]$row.slide)
    }
    # Title page: retain the original response figure, all text and university logo.
    $s=$groups[1][0];Base $s $true
    Box (Shape $s 6) 36 35 648 108;Txt (Shape $s 6) 28 -1
    Box (Shape $s 7) 36 148 400 30;Txt (Shape $s 7) 16 0 $red
    Box (Shape $s 8) 36 262 225 58;Txt (Shape $s 8) 12
    Box (Shape $s 9) 36 332 225 32;Txt (Shape $s 9) 10 0 $gray
    $fig=$s.Shapes.AddPicture((Join-Path $PSScriptRoot 'media\image3.png'),0,-1,278,171,414,232.875);$fig.Name='Original title response figure'
    $logo=$s.Shapes.AddPicture((Join-Path $PSScriptRoot 'media\image2.png'),0,-1,36,365,125,31.16);$logo.Name='Original university logo'
    # Comparison, retaining native embedded media and their playback actions.
    $s=$groups[2][0];Base $s
    Box (Shape $s 2) 36 35 308 75;Txt (Shape $s 2) 18
    Box (Shape $s 7) 376 35 308 75;Txt (Shape $s 7) 18
    (Shape $s 2).TextFrame.TextRange.Lines(1).Font.Bold=-1
    (Shape $s 7).TextFrame.TextRange.Paragraphs(1).Font.Bold=-1
    Fit (Shape $s 20) 36 121 308 222
    Fit (Shape $s 21) 376 121 308 222
    # One application at a time; the fourth stage keeps the original animated GIF.
    $appKeep=@(@(4,5,7,16,27),@(4,5,18,19,25,29),@(4,5,23,24,26),@(4,5,23,31,26))
    for($k=0;$k -lt 4;$k++) {
        $s=$groups[3][$k];ClearAnimations $s;Keep $s $appKeep[$k];Base $s
        $titleId=@(16,18,23,23)[$k];$captionId=@(27,25,26,26)[$k]
        Box (Shape $s $titleId) 36 30 648 38;Txt (Shape $s $titleId) 25 -1
        Box (Shape $s $captionId) 72 321 576 45;Txt (Shape $s $captionId) 17 0 $dark 2
        if($k -eq 0){Fit (Shape $s 7) 108 82 504 220}
        if($k -eq 1){Fit (Shape $s 19) 142 78 436 150;Fit (Shape $s 29) 142 233 436 72}
        if($k -eq 2){Fit (Shape $s 24) 220 79 280 231}
        if($k -eq 3){Fit (Shape $s 31) 165 78 390 230}
    }
    # Preserve each original equation/reveal stage without superimposed formulas.
    $mathIds=@(@(),@(17,18),@(21),@(22),@(23),@())
    for($k=0;$k -lt 6;$k++) {
        $s=$groups[4][$k];ClearAnimations $s
        Keep $s (@(2,3,4,5,11,13,14,15)+$mathIds[$k]);Base $s
        Box (Shape $s 2) 36 27 648 40;Txt (Shape $s 2) 25 -1
        $bullets=Shape $s 3;Box $bullets 42 100 228 254;Txt $bullets 16 0 $gray
        $bullets.TextFrame.TextRange.ParagraphFormat.SpaceAfter=14
        $bullets.TextFrame.TextRange.Font.Underline=0
        $bullets.TextFrame.TextRange.Paragraphs($k+1).Font.Color.RGB=$dark
        $bullets.TextFrame.TextRange.Paragraphs($k+1).Font.Bold=-1
        foreach($id in @(11,13)) {
            $b=Shape $s $id;Box $b $(if($id -eq 11){312}else{566}) 91 118 48;Txt $b 20 -1 $dark 2
            $b.TextFrame.VerticalAnchor=3;$b.Fill.Visible=-1;$b.Fill.Solid();$b.Fill.ForeColor.RGB=0xF5F3F2
            $b.Line.Visible=0
        }
        $arrow=Shape $s 14;Box $arrow 475 108 46 14;$arrow.Fill.ForeColor.RGB=$dark;$arrow.Line.Visible=0
        Box (Shape $s 15) 459 143 78 24;Txt (Shape $s 15) 13 0 $red 2
        if($k -eq 1){MathBox (Shape $s 17) 302 202 166 88 17;MathBox (Shape $s 18) 484 195 210 122 17}
        if($k -eq 2){MathBox (Shape $s 21) 299 191 393 150 23}
        if($k -eq 3){MathBox (Shape $s 22) 293 231 401 82 14}
        if($k -eq 4){MathBox (Shape $s 23) 298 211 396 107 17}
    }
    $s=$groups[5][0];Base $s
    Fit (Shape $s 20) 36 26 648 115
    MathBox (Shape $s 14) 60 146 600 57 18
    Fit (Shape $s 18) 64 211 364 156
    Box (Shape $s 22) 457 264 219 55;Txt (Shape $s 22) 18 -1
    $s=$groups[6][0];Base $s;Fit (Shape $s 8) 185 20 350 350
    $s=$groups[7][0];Base $s;Fit (Shape $s 8) 36 20 648 350
    for($k=0;$k -lt 2;$k++) {
        $s=$groups[8][$k];ClearAnimations $s
        if($k -eq 0){Keep $s @(5,6,13,14)}
        Base $s
        # Move the complete annotated illustration uniformly to retain marker registration.
        foreach($id in @(13,15,17,18)) { $sh=Shape $s $id;if($sh){$sh.Left+=14.5;$sh.Top+=15} }
        Box (Shape $s 14) 130 350 460 20;Txt (Shape $s 14) 12 0 $gray 2
        foreach($id in @(15,17)){$sh=Shape $s $id;if($sh){$sh.Line.Weight=1.5}}
    }
    $modelKeep=@(@(56,38),@(62,40),@(60,42),@(58,44,81),@(54,46),@(70,76),@(80,78))
    for($k=0;$k -lt 7;$k++) {
        $s=$groups[9][$k];ClearAnimations $s;Keep $s (@(5,6,68)+$modelKeep[$k]);Base $s
        Box (Shape $s 68) 36 352 420 20;Txt (Shape $s 68) 11 0 $gray
        $diagramId=@(56,62,60,58,54,70,80)[$k]
        if($k -lt 5) {
            Fit (Shape $s $diagramId) 148 19 424 212
            $eqId=@(38,40,42,44,46)[$k]
            MathBox (Shape $s $eqId) 102 243 516 91 18
            if($k -eq 3){Box (Shape $s 81) 120 327 540 22;Txt (Shape $s 81) 13 -1}
        } else {
            Fit (Shape $s $diagramId) 33 59 337 220
            $graph=Shape $s $(if($k -eq 5){76}else{78})
            Fit $graph 392 59 297 255
        }
    }
    $s=$groups[10][0];Base $s
    Box (Shape $s 2) 36 30 648 40;Txt (Shape $s 2) 25 -1
    Box (Shape $s 5) 36 105 630 240;Txt (Shape $s 5) 17
    (Shape $s 5).TextFrame.TextRange.ParagraphFormat.SpaceAfter=26
    $s=$groups[11][0];Base $s
    Box (Shape $s 6) 54 48 612 122;Txt (Shape $s 6) 25 -1
    Box (Shape $s 7) 80 209 566 140;Txt (Shape $s 7) 21
    (Shape $s 7).TextFrame.TextRange.ParagraphFormat.SpaceAfter=20
    foreach($s in $deck.Slides) {
        foreach($sh in $s.Shapes) {if($sh.Name -like 'Slide Number*'){$sh.TextFrame.TextRange.Text=[string]$s.SlideIndex}}
    }
    $deck.SaveAs($output)
    foreach($s in $deck.Slides){$s.Export((Join-Path $outDir ('slide-{0:D2}.png' -f $s.SlideIndex)),'PNG',1600,900)}
    Write-Output ('Saved {0} slides: {1}' -f $deck.Slides.Count,$output)
} finally { $deck.Close() }
