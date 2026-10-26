'use strict';
const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require('playwright');
async function main(){
 const [connectionFile,outputDirectory]=process.argv.slice(2);
 if(!connectionFile||!outputDirectory) throw new Error('Usage: node example-task.cjs <private-connection.json> <private-output-directory>');
 const cfg=JSON.parse(fs.readFileSync(connectionFile,'utf8').replace(/^\uFEFF/,''));
 const version=require('playwright/package.json').version;
 if(cfg.playwright!==version) throw new Error('This candidate requires identical client/server Playwright versions');
 const browser=await chromium.connect(cfg.endpoint,{timeout:30000});
 let context, result;
 try{
  context=await browser.newContext({viewport:null});
  const page=await context.newPage();
  await page.goto('https://example.com',{waitUntil:'domcontentloaded'});
  const title=await page.title();
  if(!title.includes('Example Domain')) throw new Error('Public sample page acceptance failed');
  fs.mkdirSync(outputDirectory,{recursive:true});
  const dimensions=await page.evaluate(()=>({innerWidth,innerHeight,outerWidth,outerHeight,screenWidth:screen.width,screenHeight:screen.height}));
  await page.screenshot({path:path.join(outputDirectory,'public-page.png')});
  result={title,dimensions};
 } finally {
  if(context) await context.close();
  await browser.close(); // A connected client disconnects; do not call BrowserServer.close().
 }
 fs.writeFileSync(path.join(outputDirectory,'result.json'),JSON.stringify({...result,ownContextClosed:true,clientDisconnected:true},null,2));
}
main().catch(()=>{process.stderr.write('Task failed. Inspect private evidence; endpoint and raw exceptions suppressed.\n');process.exitCode=1});
