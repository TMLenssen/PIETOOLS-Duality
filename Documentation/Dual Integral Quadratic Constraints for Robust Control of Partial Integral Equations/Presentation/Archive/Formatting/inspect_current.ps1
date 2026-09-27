$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$target='C:\Users\thijs\Desktop\Graduation_Project_TML\Presentation\Dual Integral Quadratic Contstraints for Robust Control of Partial Integral Equations.pptx'
$deck=$null
foreach($p in $ppt.Presentations){
    Write-Output ('OPEN: '+$p.FullName+' saved='+$p.Saved)
    if($p.FullName -eq $target){$deck=$p}
}
if(!$deck){$deck=$ppt.Presentations.Open($target,-1,0,0)}
$out=Join-Path $PSScriptRoot 'template_fix'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$deck.SaveCopyAs((Join-Path $out 'current.pptx'))
Write-Output ('SLIDES '+$deck.Slides.Count+' SIZE '+$deck.PageSetup.SlideWidth+' x '+$deck.PageSetup.SlideHeight)
foreach($design in $deck.Designs){
    Write-Output ('DESIGN '+$design.Name)
    foreach($layout in $design.SlideMaster.CustomLayouts){Write-Output ('LAYOUT '+$layout.Index+' '+$layout.Name+' shapes='+$layout.Shapes.Count)}
}
foreach($i in @(1,2,10,$deck.Slides.Count)){
    $slide=$deck.Slides.Item($i)
    $slide.Export((Join-Path $out ('before-'+$i+'.png')),'PNG',1280,720)
    Write-Output ('SLIDE '+$i+' layout='+$slide.CustomLayout.Name+' masterShapes='+$slide.DisplayMasterShapes)
    foreach($s in $slide.Shapes){
        $t=''; if($s.HasTextFrame -eq -1){$t=$s.TextFrame.TextRange.Text}
        Write-Output ('SHAPE '+$s.Id+' '+$s.Name+' type='+$s.Type+' box='+$s.Left+','+$s.Top+','+$s.Width+','+$s.Height+' text='+$t)
    }
}
