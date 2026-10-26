[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath)
$ErrorActionPreference='Stop'
$cfg=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
if($env:COMPUTERNAME -ne $cfg.guestComputerName -or $env:USERNAME -ne $cfg.guestUser -or (Get-CimInstance Win32_ComputerSystem).Model -ne 'Virtual Machine'){throw 'Guest ordinary identity required'}
$session=(Get-Process -Id $PID).SessionId
if($session -le 0){throw 'Interactive session required'}
$root=Join-Path $cfg.guestRoot 'desktop'
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
if(([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Worker must not run elevated'}
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -TypeDefinition @'
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public class WBDesktop {
 [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);
 public delegate bool E(IntPtr h, IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumWindows(E cb,IntPtr l);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int n);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h,IntPtr dc,uint flags);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint msg,IntPtr w,IntPtr l);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
 [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h,uint f);
 [StructLayout(LayoutKind.Sequential)] public struct POINT{public int x,y;public POINT(int a,int b){x=a;y=b;}}
 [DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr e);
 [DllImport("user32.dll")] public static extern uint SendInput(uint n,INPUT[] i,int z);
 [StructLayout(LayoutKind.Sequential)] public struct RECT{public int l,t,r,b;}
 [StructLayout(LayoutKind.Sequential)] public struct INPUT{public uint type; public U u;}
 [StructLayout(LayoutKind.Explicit)] public struct U{[FieldOffset(0)]public K k;[FieldOffset(0)]public M m;}
 [StructLayout(LayoutKind.Sequential)] public struct K{public ushort vk,scan;public uint flags,time;public UIntPtr extra;}
 [StructLayout(LayoutKind.Sequential)] public struct M{public int x,y;public uint data,flags,time;public UIntPtr extra;}
 public class W{public long hwnd;public uint pid;public string title;public RECT rect;}
 public static W[] Windows(){var a=new List<W>();EnumWindows((h,l)=>{if(IsWindowVisible(h)){var s=new StringBuilder(1024);GetWindowText(h,s,1024);uint p;GetWindowThreadProcessId(h,out p);RECT r;GetWindowRect(h,out r);if(s.Length>0)a.Add(new W{hwnd=h.ToInt64(),pid=p,title=s.ToString(),rect=r});}return true;},IntPtr.Zero);return a.ToArray();}
 public static void Key(ushort vk,bool up){var i=new INPUT{type=1,u=new U{k=new K{vk=vk,flags=up?2u:0u}}};if(SendInput(1,new[]{i},Marshal.SizeOf(typeof(INPUT)))!=1)throw new Exception("SendInput failed");}
 public static void Text(string s){foreach(char c in s.Replace("\r\n","\n").Replace('\r','\n')){if(c=='\n'||c=='\t'){ushort v=(ushort)(c=='\n'?13:9);Key(v,false);Key(v,true);continue;}var a=new[]{new INPUT{type=1,u=new U{k=new K{scan=c,flags=4}}},new INPUT{type=1,u=new U{k=new K{scan=c,flags=6}}}};if(SendInput(2,a,Marshal.SizeOf(typeof(INPUT)))!=2)throw new Exception("Unicode input failed");}}
}
'@
$displayRequest=[WBDesktop]::SetThreadExecutionState([uint32]2147483651)
if($displayRequest -eq 0){throw 'Guest display execution request failed'}
function Get-Windows {
 @([WBDesktop]::Windows() | ForEach-Object { $w=$_;$p=Get-Process -Id $w.pid -ErrorAction SilentlyContinue;if($p -and $p.SessionId -eq $session){[pscustomobject]@{hwnd=$w.hwnd;pid=$w.pid;title=$w.title;process=$p.ProcessName;path=$p.Path;session=$p.SessionId;rect=$w.rect}} })
}
function Save-Screen($path){$r=[Windows.Forms.SystemInformation]::VirtualScreen;$b=New-Object Drawing.Bitmap($r.Width,$r.Height);$g=[Drawing.Graphics]::FromImage($b);try{$g.CopyFromScreen($r.Left,$r.Top,0,0,$r.Size);$b.Save($path,[Drawing.Imaging.ImageFormat]::Png)}finally{$g.Dispose();$b.Dispose()}}
$startup=Get-Date;$archive="$root\request-history\$($startup.ToString('yyyyMMdd-HHmmss'))-$PID";$archived=@()
foreach($old in @(Get-ChildItem "$root\requests" -File)){
 if(!(Test-Path $archive)){New-Item -ItemType Directory -Path $archive -Force|Out-Null}
 $archived+=@{name=$old.Name;resultExists=(Test-Path "$root\results\$($old.BaseName).json");claimed=(Test-Path "$root\results\$($old.BaseName).claim")}
 Move-Item -LiteralPath $old.FullName -Destination (Join-Path $archive $old.Name)
}
@{pid=$PID;session=$session;user=$env:USERNAME;computer=$env:COMPUTERNAME;started=$startup.ToString('o');sourceSha256=(Get-FileHash $PSCommandPath).Hash;processCreatedUtcTicks=(Get-CimInstance Win32_Process -Filter "ProcessId=$PID").CreationDate.ToUniversalTime().Ticks.ToString();bootUtcTicks=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().Ticks.ToString();archivedRequests=$archived;archive=$archive}|ConvertTo-Json -Depth 5|Set-Content "$root\ready.json" -Encoding UTF8
while($true){
 $reqs=@(Get-ChildItem "$root\requests\*.json" -File | Sort-Object Name)
 foreach($file in $reqs){
  $id=$file.BaseName
  if($id -notmatch '^[a-zA-Z0-9_-]{1,80}$'){continue}
  if(Test-Path "$root\results\$id.json"){continue}
  if(Test-Path "$root\results\$id.claim"){continue}
  [IO.File]::WriteAllText("$root\results\$id.claim",(Get-Date -Format o))
  $result=[ordered]@{id=$id;started=(Get-Date -Format o);status='running';computer=$env:COMPUTERNAME;user=$env:USERNAME;session=$session;workerPid=$PID}
  try{
   try{$q=Get-Content $file.FullName -Raw -Encoding UTF8|ConvertFrom-Json}catch{$result.errorStage='request-json';$result.errorType=$_.Exception.GetType().FullName;throw 'Request JSON decode/parse failed'}
   if($q.id -ne $id -or $q.session -ne $session){throw 'Request identity mismatch'}
   if($q.action -notin @('observe','activate','click','type','key','close','stop')){throw 'Action denied'}
   $result.action=$q.action
   if($q.action -notin @('observe','stop')){
    $wins=@(Get-Windows);$w=@($wins|Where-Object {$_.hwnd -eq $q.hwnd -and $_.pid -eq $q.pid})
    if($w.Count -ne 1){throw 'Target missing or ambiguous'}
    $w=$w[0]
    if($w.process -notin @('notepad','CalculatorApp','Calculator')){throw 'Target process not allowed'}
    if((Get-Process LockApp,LogonUI,consent,PickerHost -ErrorAction SilentlyContinue|Where-Object SessionId -eq $session)){throw 'Secure/permission or locked desktop; no input'}
    $result.target=$w
    if($q.action -eq 'activate'){
     [WBDesktop]::ShowWindow([IntPtr]$w.hwnd,9)|Out-Null;$result.foregroundApiAccepted=[WBDesktop]::SetForegroundWindow([IntPtr]$w.hwnd)
     if([WBDesktop]::GetForegroundWindow().ToInt64() -ne $w.hwnd -and $null -ne $q.x -and $null -ne $q.y){
      if($q.x -lt 0 -or $q.y -lt 0 -or $q.x -ge ($w.rect.r-$w.rect.l) -or $q.y -ge ($w.rect.b-$w.rect.t)){throw 'Observed focus point outside target'}
      $pt=New-Object WBDesktop+POINT ($w.rect.l+$q.x),($w.rect.t+$q.y);$hit=[WBDesktop]::WindowFromPoint($pt)
      if([WBDesktop]::GetAncestor($hit,2).ToInt64() -ne $w.hwnd){throw 'Observed focus point covered by another window'}
      [WBDesktop]::SetCursorPos($pt.x,$pt.y)|Out-Null;[WBDesktop]::mouse_event(2,0,0,0,[UIntPtr]::Zero);Start-Sleep -Milliseconds 80;[WBDesktop]::mouse_event(4,0,0,0,[UIntPtr]::Zero);$result.observedFocusClick=$true
     }
     $result.foregroundAcquired=([WBDesktop]::GetForegroundWindow().ToInt64() -eq $w.hwnd)
    }
    else {
     if([WBDesktop]::GetForegroundWindow().ToInt64() -ne $w.hwnd){throw 'Target is not foreground; observe/activate separately'}
     switch($q.action){
      'click' {if($q.x -lt 0 -or $q.y -lt 0 -or $q.x -ge ($w.rect.r-$w.rect.l) -or $q.y -ge ($w.rect.b-$w.rect.t)){throw 'Point outside target'};$pt=New-Object WBDesktop+POINT ($w.rect.l+$q.x),($w.rect.t+$q.y);$hit=[WBDesktop]::WindowFromPoint($pt);if([WBDesktop]::GetAncestor($hit,2).ToInt64() -ne $w.hwnd){throw 'Point belongs to a different top-level window'};[WBDesktop]::SetCursorPos($pt.x,$pt.y)|Out-Null;[WBDesktop]::mouse_event(2,0,0,0,[UIntPtr]::Zero);[WBDesktop]::mouse_event(4,0,0,0,[UIntPtr]::Zero)}
      'type' {if($q.text.Length -gt 4096){throw 'Text too long'};[WBDesktop]::Text($q.text)}
      'key' { $map=@{ENTER=13;ESC=27;TAB=9;SPACE=32;LEFT=37;UP=38;RIGHT=39;DOWN=40;HOME=36;END=35;A=65;S=83;O=79;F4=115};if(!$map.ContainsKey([string]$q.key)){throw 'Key denied'};if($q.ctrl){[WBDesktop]::Key(17,$false)};if($q.alt){[WBDesktop]::Key(18,$false)};try{[WBDesktop]::Key($map[[string]$q.key],$false);[WBDesktop]::Key($map[[string]$q.key],$true)}finally{if($q.alt){[WBDesktop]::Key(18,$true)};if($q.ctrl){[WBDesktop]::Key(17,$true)}} }
      'close' {[WBDesktop]::Key(18,$false);try{[WBDesktop]::Key(115,$false);[WBDesktop]::Key(115,$true)}finally{[WBDesktop]::Key(18,$true)}}
     }
    }
   }
   Start-Sleep -Milliseconds 400
   $result.windows=@(Get-Windows);$result.foreground=[WBDesktop]::GetForegroundWindow().ToInt64()
   $caps=@();foreach($aw in @($result.windows|Where-Object process -in @('notepad','CalculatorApp','Calculator'))){
    $ww=$aw.rect.r-$aw.rect.l;$hh=$aw.rect.b-$aw.rect.t
    if($ww -gt 0 -and $hh -gt 0 -and $ww -le 4096 -and $hh -le 4096){
     $bm=New-Object Drawing.Bitmap($ww,$hh);$gr=[Drawing.Graphics]::FromImage($bm);$dc=$gr.GetHdc()
     try{$ok=[WBDesktop]::PrintWindow([IntPtr]$aw.hwnd,$dc,2)}finally{$gr.ReleaseHdc($dc);$gr.Dispose()}
     $cp="$root\results\$id-window-$($aw.hwnd).png";try{$bm.Save($cp,[Drawing.Imaging.ImageFormat]::Png)}finally{$bm.Dispose()}
     $caps+=@{hwnd=$aw.hwnd;path=$cp;success=$ok;sha256=(Get-FileHash $cp).Hash}
    }
   };$result.windowCaptures=$caps
   $shot="$root\results\$id.png";Save-Screen $shot
   $result.screenshot=$shot;$result.sha256=(Get-FileHash $shot).Hash;$result.status='completed'
  }catch{$result.status='failed';$result.error=$_.Exception.Message}
  $result.finished=(Get-Date -Format o)
  $result|ConvertTo-Json -Depth 8|Set-Content "$root\results\$id.tmp" -Encoding UTF8
  Move-Item -LiteralPath "$root\results\$id.tmp" -Destination "$root\results\$id.json"
  if($result.status -eq 'completed' -and $result.action -eq 'stop'){exit}
 }
 Start-Sleep -Milliseconds 250
}
