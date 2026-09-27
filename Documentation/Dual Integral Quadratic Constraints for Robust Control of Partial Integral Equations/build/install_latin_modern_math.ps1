$ErrorActionPreference='Stop'
$fontSource=Join-Path $PSScriptRoot 'slide33_cleanup/latinmodern-math.otf'
$fontDir=Join-Path $env:LOCALAPPDATA 'Microsoft/Windows/Fonts'
$fontTarget=Join-Path $fontDir 'latinmodern-math.otf'
New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
Copy-Item -LiteralPath $fontSource -Destination $fontTarget -Force
$fontRegistry='HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
New-Item -Path $fontRegistry -Force | Out-Null
New-ItemProperty -Path $fontRegistry -Name 'Latin Modern Math (OpenType)' -Value $fontTarget -PropertyType String -Force | Out-Null
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SlideFontInstall {
 [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceEx(string path, uint flags, IntPtr reserved);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
}
"@
$count=[SlideFontInstall]::AddFontResourceEx($fontTarget,0,[IntPtr]::Zero)
$result=[IntPtr]::Zero
[void][SlideFontInstall]::SendMessageTimeout([IntPtr]0xffff,0x001D,[IntPtr]::Zero,[IntPtr]::Zero,2,1000,[ref]$result)
Write-Output ('Installed Latin Modern Math for this Windows user; registered faces: '+$count)
