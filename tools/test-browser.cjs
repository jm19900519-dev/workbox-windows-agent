'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const os=require('node:os');
const Module=require('node:module');
const {spawnSync}=require('node:child_process');
const evidence=process.argv[2];
if(!evidence)throw new Error('Pass a private evidence directory outside the repository');
fs.mkdirSync(evidence,{recursive:true});
const original=Module._load;
Module._load=function(name,...rest){if(name==='playwright')return {chromium:{}};return original.call(this,name,...rest)};
const {normalizeScope,restrictState}=require('../src/browser/WorkBox-BrowserSession.cjs');
Module._load=original;
const checks=[];
function test(name,fn){fn();checks.push(name)}
test('reject object project',()=>assert.throws(()=>normalizeScope({project:{toString:()=> 'p'},user:'u',origins:['https://example.com']})));
test('reject array user',()=>assert.throws(()=>normalizeScope({project:'p',user:['u'],origins:['https://example.com']})));
test('reject non-string origin',()=>assert.throws(()=>normalizeScope({project:'p',user:'u',origins:[{toString:()=> 'https://example.com'}]})));
test('reject HTTP or path origin',()=>{for(const o of ['http://example.com','https://example.com/path'])assert.throws(()=>normalizeScope({project:'p',user:'u',origins:[o]}))});
const scope=normalizeScope({project:'p',user:'u',origins:['https://example.com','https://example.com']});
test('canonical scope deduplicates origins',()=>assert.deepEqual(scope,{project:'p',user:'u',origins:['https://example.com']}));
test('state filters unrelated cookie and origin',()=>{
 const r=restrictState({cookies:[{domain:'.example.com',name:'kept'},{domain:'unrelated.test',name:'denied'}],origins:[{origin:'https://example.com'},{origin:'https://unrelated.test'}]},scope);
 assert.equal(r.cookies.length,1);assert.equal(r.origins.length,1)
});
const config={guestComputerName:os.hostname(),guestUser:os.userInfo().username,wsPath:'ab'.repeat(32),browserCache:path.join(evidence,'synthetic-cache'),stateDirectory:path.join(evidence,'synthetic-state'),bindAddress:'127.0.0.1',port:3033};
fs.mkdirSync(config.stateDirectory,{recursive:true});
const configPath=path.join(evidence,'synthetic-browser.local.json');fs.writeFileSync(configPath,JSON.stringify(config));
const server=path.resolve(__dirname,'../src/browser/server.cjs');
test('server cache set before module load and bounded launch options',()=>{
 const code=`const fs=require('node:fs');const M=require('node:module');const expected=JSON.parse(fs.readFileSync(process.argv[2]));const old=M._load;M._load=function(n,...a){if(n==='playwright'){if(process.env.PLAYWRIGHT_BROWSERS_PATH!==expected.browserCache)throw Error('cache loaded too early');return {chromium:{launchServer:async o=>{if(o.headless!==false||o.host!==expected.bindAddress||o.port!==expected.port||o.wsPath!==expected.wsPath||o.chromiumSandbox!==true)throw Error('bad options');return {process:()=>({pid:1}),wsEndpoint:()=> 'synthetic',on:()=>{}}}}}}if(n==='playwright/package.json')return {version:'synthetic'};return old.call(this,n,...a)};const server=process.argv[1];process.argv=[process.execPath,server,process.argv[2]];require(server);`;
 const r=spawnSync(process.execPath,['-e',code,server,configPath],{encoding:'utf8',windowsHide:true,timeout:15000});
 assert.equal(r.status,0,'Synthetic server child failed');
 assert.ok(fs.existsSync(path.join(config.stateDirectory,'server.json')));
});
if(process.env.WORKBOX_TEST_PLAYWRIGHT){
 test('real dependency cache initialization order regression',()=>{
  const lib=process.env.WORKBOX_TEST_PLAYWRIGHT;
  const before=`process.env.PLAYWRIGHT_BROWSERS_PATH=process.argv[2];const p=require(process.argv[1]);process.stdout.write(String(p.chromium.executablePath().includes(process.argv[2])));`;
  const after=`const p=require(process.argv[1]);process.env.PLAYWRIGHT_BROWSERS_PATH=process.argv[2];process.stdout.write(String(p.chromium.executablePath().includes(process.argv[2])));`;
  for(const [code,expected] of [[before,'true'],[after,'false']]){
   const r=spawnSync(process.execPath,['-e',code,lib,config.browserCache],{encoding:'utf8',windowsHide:true,timeout:15000,env:{...process.env,PLAYWRIGHT_BROWSERS_PATH:''}});assert.equal(r.status,0);assert.equal(r.stdout,expected);
  }
 });
}
fs.writeFileSync(path.join(evidence,'browser-fixtures.json'),JSON.stringify({passed:true,checks,scope:'Pure scope/data fixtures and child-process cache initialization; no browser launch or real state'},null,2));
console.log(`${checks.length} browser helper fixtures passed; no real browser launched.`);
