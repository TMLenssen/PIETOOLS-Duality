$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'final.pptx'),-1,0,0)
try {
 if($d.Slides.Count -ne 56) { throw 'Wrong slide count' }
 $s=$d.Slides.Item(36)
 if($s.SlideShowTransition.EntryEffect -ne 0) { throw 'Transition remains' }
 if($s.TimeLine.MainSequence.Count -ne 1) { throw 'Unexpected animations' }
 if($s.TimeLine.MainSequence.Item(1).Timing.TriggerType -ne 1) { throw 'Video is not click-triggered' }
 $movie=$null
 foreach($sh in $s.Shapes) { if($sh.Name -eq 'Smooth sector gaps - click to play') { $movie=$sh } }
 if($null -eq $movie -or $movie.MediaFormat.Length -ne 12000) { throw 'Video unreadable' }
 $s.Export((Join-Path $PSScriptRoot 'final-preview.png'),'PNG',2160,1215)
 $settings=$d.SlideShowSettings
 $settings.ShowType=2
 $settings.RangeType=2
 $settings.StartingSlide=36
 $settings.EndingSlide=36
 $win=$settings.Run()
 try {
  Start-Sleep -Milliseconds 1600
  $player=$win.View.Player($movie.Id)
  $before=$player.CurrentPosition
  if($before -gt 50) { throw ('Video started before click: '+$before) }
  $win.View.Next()
  Start-Sleep -Milliseconds 1800
  $after=$player.CurrentPosition
  if($after -lt 300) { throw ('Video did not start on click: '+$after) }
  Write-Output ('Slideshow verified: initial position '+$before+' ms; after click '+$after+' ms.')
 } finally { $win.View.Exit() }
 Write-Output '56 slides; no entry transition; one click-triggered video; 12-second embedded media readable.'
} finally {
 # Ending a windowed slideshow may close its hidden read-only presentation.
 for($i=$ppt.Presentations.Count;$i -ge 1;$i--) {
  $opened=$ppt.Presentations.Item($i)
  if($opened.FullName -eq (Join-Path $PSScriptRoot 'final.pptx')) { $opened.Close() }
 }
}
