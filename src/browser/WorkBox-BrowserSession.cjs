'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const {chromium} = require('playwright');
function normalizeScope(value) {
 if (!value || typeof value.project !== 'string' || typeof value.user !== 'string' || !/^[a-zA-Z0-9_-]{1,80}$/.test(value.project) || !/^[a-zA-Z0-9_-]{1,80}$/.test(value.user) || !Array.isArray(value.origins) || !value.origins.length) throw new Error('Explicit project, user and site origins are required for saved state.');
 const origins = [...new Set(value.origins.map(item => {if(typeof item !== 'string')throw new Error('State scope requires string origins.');const u = new URL(item); if (u.protocol !== 'https:' || u.origin !== item) throw new Error('State scope requires exact HTTPS origins.'); return u.origin;}))].sort();
 return {project:value.project,user:value.user,origins};
}
function restrictState(state, scope) {
 const hosts = scope.origins.map(origin => new URL(origin).hostname);
 return {cookies:(state.cookies || []).filter(c => hosts.some(host => host === c.domain.replace(/^\./,'') || (c.domain.startsWith('.') && host.endsWith(c.domain)))), origins:(state.origins || []).filter(o => scope.origins.includes(o.origin))};
}
function transform(mode, text, pwsh) {
 const r = spawnSync(pwsh, ['-NoProfile','-NonInteractive','-File',path.join(__dirname,'Protect-WorkBoxState.ps1'),'-Mode',mode], {input:text, encoding:'utf8',windowsHide:true,maxBuffer:16*1024*1024});
 if(r.status !== 0 || !r.stdout) throw new Error('Private state protection failed; no state content is logged.');
 return r.stdout;
}
async function fitWindow(page) {
 const cdp = await page.context().newCDPSession(page);
 try {const {windowId} = await cdp.send('Browser.getWindowForTarget'); await cdp.send('Browser.setWindowBounds',{windowId,bounds:{windowState:'maximized'}});} finally {await cdp.detach();}
}
// Caller must hold the shared WorkBox lease for the entire returned session lifecycle.
async function openSession({configPath,pwshPath,scope,restore=false}={}) {
 if(typeof configPath !== 'string')throw new Error('Explicit local host config path required.');
 const host=JSON.parse(fs.readFileSync(configPath,'utf8').replace(/^\uFEFF/,''));
 const root=host.stateDirectory;
 const expectedVmId=host.vmId.toLowerCase();
 if(scope && (typeof pwshPath !== 'string' || !path.isAbsolute(pwshPath)))throw new Error('Explicit absolute PowerShell path required for protected state.');
 const normalized = scope ? normalizeScope(scope) : null;
 if(restore && !normalized) throw new Error('Cannot restore unscoped authentication state.');
 const key = normalized && crypto.createHash('sha256').update(JSON.stringify(normalized)).digest('hex');
 const statePath = key && path.join(root,'browser-state',key+'.dpapi');
 let state;
 if(restore && fs.existsSync(statePath)) {
  const saved = JSON.parse(transform('Unprotect',fs.readFileSync(statePath,'utf8'),pwshPath));
  if(JSON.stringify(saved.scope)!==JSON.stringify(normalized)) throw new Error('Project state scope mismatch.');
  state = restrictState(saved.state,normalized);
 }
 const cfg=JSON.parse(fs.readFileSync(path.join(root,'connection.json'),'utf8').replace(/^\uFEFF/,''));
 if(cfg.vmId.toLowerCase() !== expectedVmId) throw new Error('Remote VM identity mismatch.');
 if(cfg.playwright!==require('playwright/package.json').version)throw new Error('Client/server version mismatch.');
 const browser=await chromium.connect(cfg.endpoint,{timeout:30000});
 let context;
 try {context=await browser.newContext({viewport:null,locale:'zh-CN',...(state?{storageState:state}:{})});}
 catch {await browser.close();throw new Error('Own browser context creation failed.');}
 let closed=false;
 const pending=new Set();
 let fitFailed=false;
 context.on('page', page => {const promise=fitWindow(page).catch(()=>{if(!page.isClosed())fitFailed=true;}).finally(()=>pending.delete(promise));pending.add(promise);});
 async function settle(){await Promise.all([...pending]);if(fitFailed)throw new Error('Own browser window fitting failed.');}
 return {
  context,
  async newPage(){const page=await context.newPage();await settle();return page;},
  settle,
  async save(){
   if(!normalized)throw new Error('Cannot save anonymous or unscoped state.');
   const state=restrictState(await context.storageState({indexedDB:true}),normalized);
   const encrypted=transform('Protect',JSON.stringify({scope:normalized,state}),pwshPath);
   fs.mkdirSync(path.dirname(statePath),{recursive:true});
   const temp=statePath+'.'+crypto.randomUUID()+'.tmp';
   try {fs.writeFileSync(temp,encrypted,{flag:'wx'});fs.renameSync(temp,statePath);} finally {if(fs.existsSync(temp))fs.unlinkSync(temp);}
  },
  async close(){if(closed)return;closed=true;try{await context.close();}finally{await browser.close();}}
 };
}
module.exports={openSession,fitWindow,normalizeScope,restrictState};
