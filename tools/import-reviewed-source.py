"""Explicit, repeatable import. Never crawl a runtime directory."""
import argparse, hashlib, json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--worker', type=Path, required=True)
p.add_argument('--lease', type=Path, required=True)
p.add_argument('--evidence', type=Path, required=True)
p.add_argument('--session', type=Path)
p.add_argument('--protector', type=Path)
a = p.parse_args()
repo = Path(__file__).resolve().parents[1]

def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('Source contract changed; review required: ' + old[:70])
    return text.replace(old, new, 1)

worker = a.worker.read_text(encoding='utf-8-sig')
old = worker.splitlines()[:5]
if not old[0].startswith("$ErrorActionPreference=") or not old[4].startswith('$root='):
    raise ValueError('Worker bootstrap contract changed')
worker = worker.replace('\n'.join(old), '''[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath)
$ErrorActionPreference='Stop'
$cfg=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json
if($env:COMPUTERNAME -ne $cfg.guestComputerName -or $env:USERNAME -ne $cfg.guestUser -or (Get-CimInstance Win32_ComputerSystem).Model -ne 'Virtual Machine'){throw 'Guest ordinary identity required'}
$session=(Get-Process -Id $PID).SessionId
if($session -le 0){throw 'Interactive session required'}
$root=Join-Path $cfg.guestRoot 'desktop'
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
if(([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Worker must not run elevated'}''',1)
worker=replace_once(worker,"if($w.process -notmatch '^(douyin|notepad|CalculatorApp|Calculator|ApplicationFrameHost)$'){throw 'Target process not allowed'}", "if($w.process -notin @('notepad','CalculatorApp','Calculator')){throw 'Target process not allowed'}")
worker=replace_once(worker,"    if($w.process -eq 'douyin' -and $w.path -ne 'C:\\WorkBox\\apps\\douyin\\douyin.exe'){throw 'Douyin exact path mismatch'}\n",'')
worker=replace_once(worker,"'close','requestClose','stop'","'close','stop'")
worker=replace_once(worker,"if($q.action -ne 'requestClose' -and (Get-Process", "if((Get-Process")
line=next(line for line in worker.splitlines() if "if($q.action -eq 'requestClose')" in line)
worker=replace_once(worker,line+'\n','')
worker=replace_once(worker,"elseif($q.action -eq 'activate')", "if($q.action -eq 'activate')")
worker=replace_once(worker,"Where-Object process -eq 'douyin'", "Where-Object process -in @('notepad','CalculatorApp','Calculator')")
lease=a.lease.read_text(encoding='utf-8-sig')
line=next(line for line in lease.splitlines() if '[string]$LeaseFile =' in line)
lease=replace_once(lease,line,"    [Parameter(Mandatory)][string]$LeaseFile")
lease=lease.replace('# Test override only. Every production caller must use the same default.','# Every caller sharing a VM must use the same configured path.')
for dest,content in [('src/guest/desktop-worker.ps1',worker),('src/host/Invoke-WithWorkBoxLease.ps1',lease)]:
    target=repo/dest;target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(content,encoding='utf-8',newline='\n')
evidence={'imports':[{'kind':kind,'source':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()} for kind,path in [('worker',a.worker),('lease',a.lease)]], 'adaptations':['Explicit configuration replaces machine-specific identity and paths','Portable default native target allowlist is Notepad and Calculator only','Removed app-specific management close exception','Lease path mandatory; all callers of one VM share one path']}
if bool(a.session) != bool(a.protector):
    raise ValueError('Provide both session and protector sources')
if a.session:
    session=a.session.read_text(encoding='utf-8-sig')
    start=session.index('const root = ');end=session.index('function normalizeScope(')
    session=session[:start]+"const {chromium} = require('playwright');\n"+session[end:]
    session=replace_once(session,'function transform(mode, text) {','function transform(mode, text, pwsh) {')
    session=replace_once(session,'async function openSession({scope,restore=false}={}) {', '''async function openSession({configPath,pwshPath,scope,restore=false}={}) {
 if(typeof configPath !== 'string')throw new Error('Explicit local host config path required.');
 const host=JSON.parse(fs.readFileSync(configPath,'utf8').replace(/^\\uFEFF/,''));
 const root=host.stateDirectory;
 const expectedVmId=host.vmId.toLowerCase();
 if(scope && (typeof pwshPath !== 'string' || !path.isAbsolute(pwshPath)))throw new Error('Explicit absolute PowerShell path required for protected state.');''')
    session=replace_once(session,"path.join(root,'private','browser-state',key+'.dpapi')","path.join(root,'browser-state',key+'.dpapi')")
    session=replace_once(session,"transform('Unprotect',fs.readFileSync(statePath,'utf8'))","transform('Unprotect',fs.readFileSync(statePath,'utf8'),pwshPath)")
    session=replace_once(session,"path.join(root,'private/connection.json')","path.join(root,'connection.json')")
    session=replace_once(session,"transform('Protect',JSON.stringify({scope:normalized,state}))","transform('Protect',JSON.stringify({scope:normalized,state}),pwshPath)")
    session=replace_once(session,"const browser=await chromium.connect(cfg.endpoint,{timeout:30000});", "if(cfg.playwright!==require('playwright/package.json').version)throw new Error('Client/server version mismatch.');\n const browser=await chromium.connect(cfg.endpoint,{timeout:30000});")
    for name,content in [('WorkBox-BrowserSession.cjs',session),('Protect-WorkBoxState.ps1',a.protector.read_text(encoding='utf-8-sig'))]:
        (repo/'src/browser'/name).write_text(content,encoding='utf-8',newline='\n')
    for kind,path in [('session',a.session),('protector',a.protector)]:
        evidence['imports'].append({'kind':kind,'source':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    evidence['adaptations'].append('Frozen scoped-session repair parameterized with explicit configPath/pwshPath and host state directory; keeps project/user/origin gates and DPAPI CurrentUser')
a.evidence.parent.mkdir(parents=True,exist_ok=True)
a.evidence.write_text(json.dumps(evidence,indent=2),encoding='utf-8')
print('Imported reviewed source files; provenance saved outside release.')
