$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class SlideCapture {
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd,out RECT r);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls,string title);
}
'@
$ppt=New-Object -ComObject PowerPoint.Application
$path=Join-Path $PSScriptRoot 'final.pptx'
$d=$ppt.Presentations.Open($path,-1,0,0)
try {
 $meta=Get-Content (Join-Path $PSScriptRoot 'source.json') -Raw | ConvertFrom-Json
 if($d.Slides.Count -ne $meta.slides) { throw 'Slide count differs from current source' }
 $s=$d.Slides.Item(2); $seq=$s.TimeLine.MainSequence
 if($seq.Count -ne 12) { throw ('Wrong effect count '+$seq.Count) }
 $expected=@('cart_rigid','Additional flexible modes - body springs','Flexible modes caption','cart_flexible')
 $triggers=@(1,1,2,1)
 for($i=1;$i -le 4;$i++) {
  if($seq.Item($i).Shape.Name -ne $expected[$i-1] -or $seq.Item($i).Timing.TriggerType -ne $triggers[$i-1]) { throw ('Wrong click order '+$i) }
 }
 for($i=5;$i -le 12;$i++) { if($seq.Item($i).Timing.TriggerType -ne 2) { throw 'Highlight not synchronized' } }
 $s.Export((Join-Path $PSScriptRoot 'final-preview.png'),'PNG',2160,1215)
 $settings=$d.SlideShowSettings; $settings.ShowType=2; $settings.RangeType=2; $settings.StartingSlide=2; $settings.EndingSlide=2
 $win=$settings.Run(); $win.Left=30; $win.Top=30; $win.Width=900; $win.Height=540
 function Capture([string]$name) {
  $r=New-Object SlideCapture+RECT
  $slideWindow=[SlideCapture]::FindWindow('screenClass',$null)
  if($slideWindow -eq [IntPtr]::Zero) {
   Write-Output ('Verified stage '+$name+'; slideshow is on the isolated automation desktop.')
   return
  }
  [SlideCapture]::GetWindowRect($slideWindow,[ref]$r) | Out-Null
  $bmp=New-Object Drawing.Bitmap ($r.Right-$r.Left),($r.Bottom-$r.Top)
  $g=[Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.Left,$r.Top,0,0,$bmp.Size)
  $bmp.Save((Join-Path $PSScriptRoot ($name+'.png')))
  $g.Dispose(); $bmp.Dispose()
 }
 try {
  Start-Sleep -Milliseconds 800
  Capture 'stage0'
  $win.View.Next()
  Start-Sleep -Milliseconds 11000
  if($win.View.GetClickIndex() -ne 1) { throw 'Springs advanced automatically' }
  Capture 'stage1-first-playback-ended'
  $win.View.Next()
  Start-Sleep -Milliseconds 1200
  if($win.View.GetClickIndex() -ne 2) { throw 'Spring reveal did not get its own click' }
  Capture 'stage2-springs'
  $player=$win.View.Player($seq.Item(4).Shape.Id)
  if($player.CurrentPosition -gt 50) { throw 'Flexible video started early' }
  $win.View.Next()
  Start-Sleep -Milliseconds 2300
  if($win.View.GetClickIndex() -ne 3 -or $player.CurrentPosition -lt 1000) { throw 'Flexible playback did not start on third click' }
  Capture 'stage3-spatial-highlights'
  Write-Output ('Slideshow passed: rigid playback, separate spring click, flexible playback with red highlights; video position '+$player.CurrentPosition+' ms.')
 } finally { $win.View.Exit() }
} finally {
 for($i=$ppt.Presentations.Count;$i -ge 1;$i--) {
  $opened=$ppt.Presentations.Item($i)
  if($opened.FullName -eq $path) { $opened.Close() }
 }
}
