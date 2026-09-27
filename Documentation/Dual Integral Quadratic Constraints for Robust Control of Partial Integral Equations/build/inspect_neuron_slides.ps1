$ErrorActionPreference='Stop'
$out=Join-Path $PSScriptRoot 'neuron_simulation_slides'
$source=Get-ChildItem -LiteralPath 'C:/Users/thijs/Desktop/Graduation_Project_TML/Presentation' -Filter 'Dual*.pptx' | Select-Object -First 1
$ppt=New-Object -ComObject PowerPoint.Application
$deck=$null;$opened=$false
foreach($d in $ppt.Presentations){if($d.FullName -eq $source.FullName){$deck=$d;break}}
if($null -eq $deck){$deck=$ppt.Presentations.Open($source.FullName,-1,0,0);$opened=$true}
try {
 $deck.SaveCopyAs((Join-Path $out 'original.pptx'))
 foreach($n in @(12,13,14,15)){
  $deck.Slides.Item($n).Export((Join-Path $out ('before-'+$n+'.png')),'PNG',1600,900)
  $info=@()
  foreach($s in $deck.Slides.Item($n).Shapes){
   $txt='';if($s.HasTextFrame -eq -1){$txt=$s.TextFrame.TextRange.Text}
   $info += [pscustomobject]@{id=$s.Id;name=$s.Name;left=$s.Left;top=$s.Top;width=$s.Width;height=$s.Height;text=$txt}
  }
  $info | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $out ('shapes-'+$n+'.json')) -Encoding UTF8
 }
 [pscustomobject]@{source=$source.FullName;hash=(Get-FileHash -LiteralPath $source.FullName).Hash;saved=$deck.Saved;opened=$opened} | ConvertTo-Json | Set-Content (Join-Path $out 'source.json') -Encoding UTF8
 Write-Output 'Captured current neural-population slides.'
}finally{if($opened){$deck.Close()}}




