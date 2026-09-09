// Optional browser verification: node browser.test.mjs /path/to/playwright/index.mjs
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile, mkdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const {chromium} = await import(process.argv[2] || 'playwright');
const root = fileURLToPath(new URL('./dist/', import.meta.url));
const evidence = fileURLToPath(new URL('./evidence/', import.meta.url));
await mkdir(evidence, {recursive:true});
const server = createServer(async (request, response) => {
  const name = new URL(request.url, 'http://localhost').pathname;
  const filename = path.join(root, name === '/' ? 'index.html' : name);
  if (!filename.startsWith(root)) { response.writeHead(403).end(); return; }
  try {
    const contents = await readFile(filename);
    response.setHeader('Content-Type', ({'.html':'text/html','.mjs':'text/javascript','.js':'text/javascript','.json':'application/json','.css':'text/css'})[path.extname(filename)] || 'application/octet-stream');
    response.end(contents);
  } catch { response.writeHead(404).end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const url = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch({headless:true});
const page = await browser.newPage({viewport:{width:1024,height:1000}});
const catalog = JSON.parse(await readFile(path.join(root,'cameras.json'),'utf8'));
async function chooseCamera(id) {
  const camera=catalog.cameras.find(c=>c.id===id);
  await page.selectOption('#brand',camera.brand);
  await page.selectOption('#camera',id);
}
const errors = [];
page.on('pageerror', error => errors.push(error.message));
try {
  await page.goto(url);
  await page.locator('#form').waitFor({state:'visible'});
  assert.equal(await page.locator('#brand option').count(),new Set(catalog.cameras.map(c=>c.brand)).size);
  await page.selectOption('#setting','normal');
  assert.equal(await page.locator('#rows tr').count(),5);
  assert.equal(await page.locator('#rows tr').nth(3).locator('td').innerText(),'8 hr 30 min');
  assert.equal(await page.locator('input').count(),0);
  await page.selectOption('#setting','maximum');
  assert.equal(await page.locator('#rows tr').nth(3).locator('td').innerText(),'7 hr');
  await page.selectOption('#setting','normal');
  assert.equal(await page.locator('#rows tr').nth(3).locator('td').innerText(),'8 hr 30 min');
  assert.match(await page.locator('#recording-details').innerText(),/4K/);
  await page.waitForFunction(()=>!document.querySelector('#camera-photo').hidden);
  await page.screenshot({path:path.join(evidence,'desktop.png'),fullPage:true});
  await page.selectOption('#channels','front-rear');
  assert.equal(await page.locator('#rows tr').nth(3).locator('td').innerText(),'10 hr 30 min');
  await page.selectOption('#channels','front');
  assert.equal(await page.locator('#rows tr').nth(3).locator('td').innerText(),'17 hr');
  await chooseCamera('blackvue-elite-9');
  assert.equal(await page.locator('#channels option').count(),2);
  await chooseCamera('viofo-a119-mini');
  assert.equal(await page.locator('#channels').isDisabled(),true);
  await chooseCamera('viofo-a329s');
  await page.selectOption('#channels','front-rear-interior');
  assert.ok(!(await page.locator('#rows').innerText()).includes(' – '));
  await chooseCamera('thinkware-u3000-pro');
  assert.equal(await page.locator('#partition-note').isVisible(),true);
  await chooseCamera('thinkware-u1000-plus');
  await page.selectOption('#channels','front-rear');
  assert.match(await page.locator('#recording-details').innerText(),/Front/);
  assert.match(await page.locator('#recording-details').innerText(),/1080p/);
  assert.equal(await page.locator('#setting-control').isHidden(),true);
  assert.match(await page.locator('#recording-details').innerText(),/MB\/min/);
  assert.ok(!(await page.locator('.method').textContent()).includes('Viofo'));
  await chooseCamera('blackvue-elite-10');
  await page.selectOption('#channels','front-rear');
  await page.selectOption('#setting','normal');
  const medium = await page.locator('#rows').innerText();
  await page.selectOption('#setting','maximum');
  assert.notEqual(await page.locator('#rows').innerText(),medium);
  assert.equal(await page.locator('#recording-details').getByText('4K, 30 fps',{exact:true}).count(),2);
  assert.match(await page.locator('#recording-details').innerText(),/450 MB\/min/);
  assert.equal(await page.locator('#shopping-links a').first().getAttribute('href'),'https://geni.us/BlackvueElite10-2CH');
  await chooseCamera('vueroid-s1-4k-infinite');
  await page.selectOption('#channels','front-rear-interior');
  assert.match(await page.locator('#recording-details').innerText(),/Cabin/);
  assert.match(await page.locator('#camera-note').textContent(),/reserved space/);
  await chooseCamera('viofo-a119-mini-2');
  await page.selectOption('#setting','measured-60fps');
  assert.match(await page.locator('#recording-details').innerText(),/60 fps/);
  assert.match(await page.locator('#basis').textContent(),/Quality menu setting unknown/);
  await chooseCamera('blackvue-elite-9');
  const blackvueModels=await page.locator('#camera option').allTextContents();
  assert.ok(blackvueModels.indexOf('Elite 9') < blackvueModels.indexOf('Elite 10'));
  assert.ok(blackvueModels.includes('DR900X Plus'));
  assert.ok(blackvueModels.every(m=>!m.includes('Viofo')));
  await chooseCamera('vantrue-n5');
  const firstResolution=await page.locator('#rows').innerText();
  await page.selectOption('#setting','1944p');
  assert.notEqual(await page.locator('#rows').innerText(),firstResolution);
  assert.equal(await page.locator('.channel-row').count(),4);
  await chooseCamera('70mai-4k-omni-x800');
  await page.selectOption('#channels','front');
  await page.selectOption('#setting','60fps');
  assert.match(await page.locator('#recording-details').innerText(),/60 fps/);
  // Every public camera, configuration and setting must render and update safely.
  for (const id of catalog.cameras.map(c=>c.id)) {
    await chooseCamera(id);
    for (const setup of await page.locator('#channels option').evaluateAll(nodes=>nodes.map(n=>n.value))) {
      if (await page.locator('#channels').isEnabled()) await page.selectOption('#channels',setup);
      for (const mode of await page.locator('#setting option').evaluateAll(nodes=>nodes.map(n=>n.value))) {
        if (await page.locator('#setting').isEnabled()) await page.selectOption('#setting',mode);
        assert.equal(await page.locator('#rows tr').count(),5);
        assert.ok(!(await page.locator('#rows').innerText()).match(/NaN|undefined/));
      }
    }
  }
  await chooseCamera('viofo-a229-pro');
  await page.selectOption('#channels','front-rear-interior');
  await page.setViewportSize({width:375,height:812});
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  await page.screenshot({path:path.join(evidence,'mobile.png'),fullPage:true});
  await page.goto(`${url}/demo.html`);
  const frame = page.frameLocator('iframe');
  await frame.locator('#form').waitFor({state:'visible'});
  await page.waitForFunction(() => document.querySelector('iframe').style.height !== '1100px');
  const before = await page.locator('iframe').evaluate(el => el.offsetHeight);
  await frame.locator('.method summary').click();
  await page.waitForFunction(height => document.querySelector('iframe').offsetHeight > height, before);
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  await page.screenshot({path:path.join(evidence,'embedded-mobile.png'),fullPage:true});
  // Missing images collapse cleanly without losing recording data.
  await page.goto(url);
  await page.route('**/images/blackvue-elite-10.*',route=>route.fulfill({status:404,body:''}));
  await chooseCamera('blackvue-elite-10');
  await page.waitForFunction(()=>document.querySelector('#camera-photo').hidden);
  assert.equal(await page.locator('#rows tr').count(),5);
  // New source types must not become fictitious file sizes or manufacturer claims.
  await chooseCamera('vueroid-s1-qhd-infinite');
  await page.selectOption('#channels','front');
  await page.selectOption('#setting','submitted-60fps');
  assert.match(await page.locator('#recording-details').innerText(), /60 fps/);
  assert.match(await page.locator('#size-note').innerText(), /padding/);
  assert.match(await page.locator('#source').textContent(), /submitted/);
  await chooseCamera('70mai-t800');
  assert.match(await page.locator('#size-note').innerText(), /rear-camera version/);
  assert.ok(!(await page.locator('#recording-details').innerText()).includes('MB/min'));
  assert.equal(await page.locator('figcaption').count(),0);
  await chooseCamera('viofo-a229-pro');
  assert.ok(!(await page.locator('#shopping-links').innerText()).includes('memory cards'));
  // The summary precedes a vertical comparison at every viewport.
  for (const width of [740,620,375,320]) {
    await page.setViewportSize({width,height:1000});
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    const layout=await page.evaluate(()=>{const d=document.querySelector('.channel-summary').getBoundingClientRect();const t=document.querySelector('table').getBoundingClientRect();return {detailsRight:d.right,detailsBottom:d.bottom,tableLeft:t.left,tableTop:t.top};});
    assert.ok(layout.tableTop>=layout.detailsBottom);
    const cells=await page.locator('#rows tr').evaluateAll(rows=>rows.map(r=>{const b=r.getBoundingClientRect();return {x:b.x,y:b.y};}));
    assert.ok(cells[1].y>cells[0].y && cells[1].x===cells[0].x);
  }
  // Setup photos change without moving controls; slow obsolete loads cannot win.
  await chooseCamera('vueroid-s1-4k-infinite');
  await page.setViewportSize({width:740,height:1000});
  const geometry=()=>page.locator('#channels').boundingBox();
  let baseline;
  const sources=new Set();
  for(const setup of ['front','front-rear','front-rear-interior']) {
    await page.selectOption('#channels',setup);
    await page.waitForFunction(()=>!document.querySelector('#camera-photo').hidden);
    sources.add(await page.locator('#product-image').getAttribute('src'));
    const box=await geometry();
    if(baseline) assert.deepEqual(box,baseline); else baseline=box;
  }
  assert.equal(sources.size,3);
  await page.selectOption('#channels','front-interior');
  assert.equal(await page.locator('#camera-photo').isHidden(),true);
  assert.deepEqual(await geometry(),baseline);
  await page.route('**/images/vueroid-s1-4k-infinite-front.webp',async route=>{
    await new Promise(resolve=>setTimeout(resolve,150));await route.continue();
  });
  await page.selectOption('#channels','front');
  await page.selectOption('#channels','front-rear-interior');
  await page.waitForFunction(()=>!document.querySelector('#camera-photo').hidden);
  await page.waitForTimeout(200);
  assert.match(await page.locator('#product-image').getAttribute('src'),/front-rear-interior/);
  assert.equal(await page.locator('.eyebrow').count(),0);
  assert.ok(!(await page.locator('body').innerText()).includes('Affiliate links:'));
  // WordPress can enqueue the loader after the iframe has finished loading.
  await page.setContent(`<iframe data-vr-recording-time src="${url}/index.html" style="width:100%;height:1100px;border:0"></iframe>`);
  await page.frameLocator('iframe').locator('#form').waitFor({state:'visible'});
  await page.addScriptTag({url:`${url}/embed.js`});
  await page.waitForFunction(() => document.querySelector('iframe').style.height !== '1100px');
  const measuredHeight = await page.locator('iframe').evaluate(el => el.offsetHeight);
  await page.evaluate(() => window.postMessage({type:'vr-recording-height',height:5999}, location.origin));
  await page.waitForTimeout(100);
  assert.equal(await page.locator('iframe').evaluate(el => el.offsetHeight), measuredHeight);
  // The inline standalone loader remains repeatable within a post.
  await page.setContent('<div id="one"></div><div id="two"></div>');
  await page.addScriptTag({url:`${url}/embed.js`});
  await page.addScriptTag({url:`${url}/embed.js`});
  assert.equal(await page.locator('iframe').count(), 2);
  await page.goto(url);
  await chooseCamera('botslab-g980h');
  assert.match(await page.locator('#recording-details').innerText(), /Left/);
  assert.match(await page.locator('#recording-details').innerText(), /Right/);
  assert.match(await page.locator('#size-note').innerText(), /Includes file padding/);
  assert.ok(!(await page.locator('#method-detail').innerText()).includes('manufacturer'));
  await page.setViewportSize({width:1280,height:1000});
  await page.screenshot({path:path.join(evidence,'storage-desktop.png'),fullPage:true});
  await page.setViewportSize({width:390,height:844});
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  await page.screenshot({path:path.join(evidence,'storage-mobile.png'),fullPage:true});
  await page.route('**/cameras.json', route => route.fulfill({status:503,body:'unavailable'}));
  await page.goto(url);
  await page.locator('#loading').waitFor({state:'visible'});
  await page.waitForFunction(()=>document.querySelector('#loading').textContent.includes('couldn’t load'));
  assert.equal(await page.locator('#form').isHidden(),true);
  assert.deepEqual(errors, []);
  console.log(`Browser checks passed: ${catalog.cameras.length} cameras, 1/2/3CH chart changes, five card sizes, single-channel controls, single time estimates, desktop/mobile, iframe resizing, delayed loader, forged-message rejection, multiple embeds, missing-data state; no JS errors.`);
} finally {
  await browser.close();
  server.close();
}
