'use strict';
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const configPath=process.argv[2];
if(!configPath) throw new Error('Pass the private guest browser configuration path');
const cfg=JSON.parse(fs.readFileSync(configPath,'utf8').replace(/^\uFEFF/,''));
if(os.hostname().toLowerCase()!==cfg.guestComputerName.toLowerCase() || os.userInfo().username.toLowerCase()!==cfg.guestUser.toLowerCase()) throw new Error('Wrong guest computer/user');
if(!/^[0-9a-f]{64}$/.test(cfg.wsPath)) throw new Error('Invalid locally generated capability');
process.env.PLAYWRIGHT_BROWSERS_PATH=cfg.browserCache;
const {chromium}=require('playwright');
(async()=>{
 const server=await chromium.launchServer({headless:false,host:cfg.bindAddress,port:cfg.port,wsPath:cfg.wsPath,chromiumSandbox:true,timeout:120000});
 const record={timestamp:new Date().toISOString(),hostname:os.hostname(),user:os.userInfo().username,nodePid:process.pid,browserPid:server.process().pid,playwright:require('playwright/package.json').version,headless:false,endpoint:server.wsEndpoint()};
 const dest=path.join(cfg.stateDirectory,'server.json');
 fs.writeFileSync(dest+'.tmp',JSON.stringify(record,null,2));fs.renameSync(dest+'.tmp',dest);
 server.on('close',()=>process.exit(0));
})().catch(()=>{fs.writeFileSync(path.join(cfg.stateDirectory,'server-error.txt'),'Browser startup failed; inspect locally. No endpoint or exception is logged.');process.exit(1)});
