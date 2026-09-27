param([string]$AssetDirectory='')
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out=Join-Path $workspace 'build\simple_deck'
if($AssetDirectory){$out=(Resolve-Path -LiteralPath $AssetDirectory).Path}
$plan=Get-Content -LiteralPath (Join-Path $out 'plan.json') -Raw | ConvertFrom-Json
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$ppt.Presentations.Open((Join-Path $out 'source.pptx'),0,0,0)
$exports=@()
function FindShape($slide,$ident){foreach($shape in $slide.Shapes){if($shape.Id -eq $ident){return $shape}};throw "Shape not found: $ident"}
function ExportLayer($slide,$ids,$bounds,$file){
    $names=@()
    foreach($ident in $ids){$shape=FindShape $slide $ident;$shape.Name="Bake-label-$ident";$names+=$shape.Name}
    $anchor=$slide.Shapes.AddShape(1,$bounds[0],$bounds[1],$bounds[2],$bounds[3]);$anchor.Fill.Visible=0;$anchor.Line.Visible=0;$names+=$anchor.Name
    $group=$slide.Shapes.Range([object[]]$names).Group()
    $record=@{file=$file;box=@([double]$group.Left,[double]$group.Top,[double]$group.Width,[double]$group.Height)}
    $group.Export((Join-Path $out $file),2,1440,810,1)
    $ungroup=$group.Ungroup();$anchor.Delete()
    return $record
}
try {
    foreach($spec in $plan.slides){
        $slide=$deck.Slides.Item($spec.index)
        foreach($g in $spec.groups){
            $file="group-$($spec.index)-$($g.id).png"
            $canvas=@(-72,-72,($plan.width+144),($plan.height+144))
            $layer=ExportLayer $slide @($g.id) $canvas $file
            $exports+=@{kind='group';slide=$spec.index;id=$g.id;file=$layer.file;box=$layer.box}
        }
        foreach($v in $spec.videos){
            $bounds=@([double]$v.box[0],[double]$v.box[1],[double]$v.box[2],[double]$v.box[3])
            foreach($l in $v.labels){
                $left=[Math]::Min($bounds[0],$l.box[0]);$top=[Math]::Min($bounds[1],$l.box[1])
                $right=[Math]::Max(($bounds[0]+$bounds[2]),($l.box[0]+$l.box[2]));$bottom=[Math]::Max(($bounds[1]+$bounds[3]),($l.box[1]+$l.box[3]))
                $bounds=@($left,$top,($right-$left),($bottom-$top))
            }
            $bounds=@(-72,-72,($plan.width+144),($plan.height+144))
            $static=@();$dynamic=@()
            foreach($l in $v.labels){if($v.tracks.PSObject.Properties.Name -contains [string]$l.id){$dynamic+=$l.id}else{$static+=$l.id}}
            $layer=ExportLayer $slide $static $bounds "video-$($spec.index)-$($v.id)-static.png"
            $exports+=@{kind='static';slide=$spec.index;id=$v.id;file=$layer.file;box=$layer.box}
            foreach($ident in $dynamic){
                $layer=ExportLayer $slide @($ident) $bounds "video-$($spec.index)-$($v.id)-moving-$ident.png"
                $exports+=@{kind='moving';slide=$spec.index;id=$v.id;label=$ident;file=$layer.file;box=$layer.box}
            }
        }
        if($spec.groups.Count -gt 0 -or $spec.videos.Count -gt 0){Write-Output "Exported graphics on slide $($spec.index)"}
    }
    $exports | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $out 'exports.json') -Encoding UTF8
} finally {$deck.Saved=-1;$deck.Close()}
