// usage: node itchpw.js <page_url> <outdir> [upload name substrings...]
const {chromium}=require('playwright');const path=require('path');
(async()=>{const [page,out,...subs]=process.argv.slice(2);
const b=await chromium.launch();const ctx=await b.newContext({acceptDownloads:true});const pg=await ctx.newPage();
await pg.goto(page);
const r=await pg.evaluate(async(p)=>{const c=document.querySelector('meta[name=csrf_token]').getAttribute('value');const res=await fetch(p+'/download_url',{method:'POST',body:new URLSearchParams({csrf_token:c})});return res.json();},page);
await pg.goto(r.url);
await pg.waitForSelector('[data-upload_id]',{timeout:30000});const ups=await pg.$$eval('.upload_list_widget .upload',els=>els.map(e=>({id:e.querySelector('[data-upload_id]')?.getAttribute('data-upload_id'),name:e.querySelector('.name')?.getAttribute('title')})));
console.log(JSON.stringify(ups));
for(const u of ups){if(subs.length&&!subs.some(s=>u.name.includes(s)))continue;
 const [dl]=await Promise.all([pg.waitForEvent('download',{timeout:600000}),pg.click(`[data-upload_id="${u.id}"]`)]);
 const f=path.join(out,dl.suggestedFilename());await dl.saveAs(f);console.log('got',f);}
await b.close();})();
