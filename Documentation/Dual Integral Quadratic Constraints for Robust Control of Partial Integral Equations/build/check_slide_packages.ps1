$ErrorActionPreference='Stop'
$ppt=New-Object -ComObject PowerPoint.Application
foreach($name in @('original','only33','only34','insert_only')) {
 try { $d=$ppt.Presentations.Open((Join-Path $PSScriptRoot ('slides33_34/'+$name+'.pptx')),-1,0,0);Write-Output ($name+': opened '+$d.Slides.Count+' slides');$d.Close() } catch { Write-Output ($name+': '+$_.Exception.Message) }
}
