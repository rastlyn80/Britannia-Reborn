param([Parameter(Mandatory)][int]$ServerProcessId,[Parameter(Mandatory)][ValidateSet('save','shutdown')][string]$Command)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$target = Get-CimInstance Win32_Process -Filter "ProcessId=$ServerProcessId"
$expected = [IO.Path]::GetFullPath("$root/.tools/dotnet-server/dotnet.exe")
if (!$target -or $target.ExecutablePath -ne $expected -or $target.CommandLine -notmatch 'ModernUO\.dll') {
  throw 'The target is not this workspace''s ModernUO host.'
}
# Windows console input is the existing server's stdin. This sends only the
# two whitelisted maintenance commands; it never terminates a process by force.
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class PreviewConsoleInput {
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
 public struct Key { [MarshalAs(UnmanagedType.Bool)] public bool Down; public ushort Repeat, Code, Scan; public char Character; public uint Modifiers; }
 [StructLayout(LayoutKind.Explicit, Size=20)]
 public struct Record { [FieldOffset(0)] public ushort Type; [FieldOffset(4)] public Key Value; }
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool AttachConsole(uint pid);
 [DllImport("kernel32.dll")] static extern bool FreeConsole();
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string name,uint access,uint share,IntPtr security,uint mode,uint flags,IntPtr template);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool WriteConsoleInputW(SafeFileHandle input,Record[] records,uint length,out uint written);
 public static void Send(uint pid,string text) {
  FreeConsole();
  if(!AttachConsole(pid)) throw new Win32Exception(Marshal.GetLastWin32Error());
  try {
   using var input=CreateFile("CONIN$",0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero);
   if(input.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
   var records=new Record[text.Length*2];
   for(int i=0;i<text.Length;i++) {
    var key=new Key {Down=true,Repeat=1,Character=text[i],Code=(ushort)(text[i]=='\r'?13:0)};
    records[i*2]=new Record {Type=1,Value=key};
    key.Down=false; records[i*2+1]=new Record {Type=1,Value=key};
   }
   if(!WriteConsoleInputW(input,records,(uint)records.Length,out var written) || written!=records.Length) throw new Win32Exception(Marshal.GetLastWin32Error());
  } finally { FreeConsole(); }
 }
}
'@
[PreviewConsoleInput]::Send($ServerProcessId,($Command+"`r"))
Write-Output "Sent $Command to the verified local server console."
