$ErrorActionPreference='Stop'
$source=Get-ChildItem -LiteralPath 'C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation' -Filter 'Dual*.pptx' | Select-Object -First 1
$out=Join-Path $PSScriptRoot 'slide33_cleanup'
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$null
$opened=$false
foreach($p in $ppt.Presentations) { if($p.FullName -eq $source.FullName) { $deck=$p; break } }
if($null -eq $deck) { $deck=$ppt.Presentations.Open($source.FullName,-1,0,0); $opened=$true }
try {
 $deck.Slides.Item(33).Export((Join-Path $out 'before.png'),'PNG',1920,1080)
 $deck.SaveCopyAs((Join-Path $out 'original.pptx'))
 $info=@()
 function Read-Shape($s,$parent) {
  $t=''
  if($s.HasTextFrame -eq -1) { $t=$s.TextFrame.TextRange.Text }
  $script:info += [pscustomobject]@{id=$s.Id;name=$s.Name;parent=$parent;type=$s.Type;left=$s.Left;top=$s.Top;width=$s.Width;height=$s.Height;rotation=$s.Rotation;text=$t}
  if($s.Type -eq 6) { foreach($c in $s.GroupItems) { Read-Shape $c $s.Name } }
 }
 foreach($s in $deck.Slides.Item(33).Shapes) { Read-Shape $s '' }
 $info | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $out 'shapes.json') -Encoding UTF8
 [pscustomobject]@{source=$source.FullName;hash=(Get-FileHash -LiteralPath $source.FullName).Hash;saved=$deck.Saved;opened=$opened;slides=$deck.Slides.Count;width=$deck.PageSetup.SlideWidth;height=$deck.PageSetup.SlideHeight} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'source.json') -Encoding UTF8
 Write-Output 'Rendered slide 33 and saved a working copy.'
} finally { if($opened) { $deck.Close() } }
