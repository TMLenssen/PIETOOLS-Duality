$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'attach.ps1')
$d=$ppt.Presentations.Open((Join-Path $PSScriptRoot 'source.pptx'),-1,0,0)
try{
$items=@()
foreach($s in $d.Slides){
$s.Export((Join-Path $PSScriptRoot ('before{0:D3}.png' -f $s.SlideIndex)),'PNG',960,540)
$shapes=@();foreach($sh in $s.Shapes){$txt='';$font='';$sz=0;if($sh.HasTextFrame){$txt=$sh.TextFrame.TextRange.Text;$font=$sh.TextFrame.TextRange.Font.Name;$sz=$sh.TextFrame.TextRange.Font.Size};$shapes+=@{id=$sh.Id;name=$sh.Name;type=$sh.Type;x=$sh.Left;y=$sh.Top;w=$sh.Width;h=$sh.Height;text=$txt;font=$font;size=$sz}}
$items+=@{slide=$s.SlideIndex;id=$s.SlideID;effects=$s.TimeLine.MainSequence.Count;transition=$s.SlideShowTransition.EntryEffect;shapes=$shapes}
}
$items | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'inventory.json') -Encoding UTF8
Write-Output ('Exported '+$d.Slides.Count+' slides.')
}finally{$d.Close()}
