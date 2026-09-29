Add-Type @"
using System;using System.Text;using System.Runtime.InteropServices;
public class PptNative {
public delegate bool EnumProc(IntPtr hwnd,IntPtr l);
[DllImport("user32.dll")]public static extern bool EnumChildWindows(IntPtr h,EnumProc p,IntPtr l);
[DllImport("user32.dll")]public static extern bool EnumWindows(EnumProc p,IntPtr l);
[DllImport("user32.dll",CharSet=CharSet.Unicode)]public static extern int GetClassName(IntPtr h,StringBuilder s,int n);
[DllImport("oleacc.dll")]public static extern int AccessibleObjectFromWindow(IntPtr h,uint id,ref Guid iid,[MarshalAs(UnmanagedType.IDispatch)]out object o);
public static object App;
public static bool Child(IntPtr h,IntPtr l){var b=new StringBuilder(256);GetClassName(h,b,256);if(b.ToString()=="mdiClass"){object o;Guid g=new Guid("00020400-0000-0000-C000-000000000046");if(AccessibleObjectFromWindow(h,0xFFFFFFF0,ref g,out o)==0&&o!=null)App=o;}return true;}
public static bool Top(IntPtr h,IntPtr l){EnumChildWindows(h,Child,IntPtr.Zero);return true;}
public static object Get(){EnumWindows(Top,IntPtr.Zero);return App;}
}
"@
$native=[PptNative]::Get()
if($native){$ppt=$native.Application}else{$ppt=New-Object -ComObject PowerPoint.Application}
