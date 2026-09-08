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
const errors = [];
page.on('pageerror', error => errors.push(error.message));
try {
  await page.goto(url);
  await page.locator('#form').waitFor({state:'visible'});
  assert.equal(await page.locator('#camera option').count(),31);
  assert.equal(await page.locator('#rows tr').count(),5);
  assert.equal(await page.locator('#rows tr').nth(3).locator('td').innerText(),'8 hr 30 min');
  assert.equal(await page.locator('input').count(),0);
  await page.selectOption('#setting','maximum');
  assert.equal(await page.locator('#rows tr').nth(3).locator('td').innerText(),'7 hr');
  await page.selectOption('#setting','normal');
  assert.equal(await page.locator('#rows tr').nth(3).locator('td').innerText(),'8 hr 30 min');
  assert.match(await page.locator('#recording-details').innerText(),/4K/);
  await page.screenshot({path:path.join(evidence,'desktop.png'),fullPage:true});
  await page.selectOption('#channels','front-rear');
  assert.equal(await page.locator('#rows tr').nth(3).locator('td').innerText(),'10 hr 30 min');
  await page.selectOption('#channels','front');
  assert.equal(await page.locator('#rows tr').nth(3).locator('td').innerText(),'17 hr');
  await page.selectOption('#camera','blackvue-elite-9');
  assert.equal(await page.locator('#channels option').count(),2);
  await page.selectOption('#camera','viofo-a119-mini');
  assert.equal(await page.locator('#channels').isDisabled(),true);
  await page.selectOption('#camera','viofo-a329s');
  await page.selectOption('#channels','front-rear-interior');
  assert.match(await page.locator('#rows').innerText(),/ – /);
  await page.selectOption('#camera','thinkware-u3000-pro');
  assert.equal(await page.locator('#partition-note').isVisible(),true);
  await page.selectOption('#camera','thinkware-u1000-plus');
  assert.match(await page.locator('#recording-details').innerText(),/front: 4K.*rear: 1080p/);
  assert.ok(!(await page.locator('.method').textContent()).includes('Viofo'));
  await page.selectOption('#camera','blackvue-elite-10');
  await page.selectOption('#channels','front-rear');
  const medium = await page.locator('#rows').innerText();
  await page.selectOption('#setting','maximum');
  assert.notEqual(await page.locator('#rows').innerText(),medium);
  assert.match(await page.locator('#recording-details').innerText(),/front: 4K.*rear: 4K/);
  assert.equal(await page.locator('#shopping-links a').first().getAttribute('href'),'https://geni.us/BlackvueElite10-2CH');
  await page.selectOption('#camera','vueroid-s1-4k-infinite');
  await page.selectOption('#channels','front-rear-interior');
  assert.match(await page.locator('#recording-details').innerText(),/cabin: 1080p/);
  assert.match(await page.locator('#camera-note').textContent(),/reserved space/);
  await page.selectOption('#camera','viofo-a119-mini-2');
  await page.selectOption('#setting','measured-60fps');
  assert.match(await page.locator('#recording-details').innerText(),/60 fps/);
  assert.match(await page.locator('#basis').textContent(),/Quality menu setting unknown/);
  // Every public camera, configuration and setting must render and update safely.
  for (const id of await page.locator('#camera option').evaluateAll(nodes=>nodes.map(n=>n.value))) {
    await page.selectOption('#camera',id);
    for (const setup of await page.locator('#channels option').evaluateAll(nodes=>nodes.map(n=>n.value))) {
      if (await page.locator('#channels').isEnabled()) await page.selectOption('#channels',setup);
      for (const mode of await page.locator('#setting option').evaluateAll(nodes=>nodes.map(n=>n.value))) {
        if (await page.locator('#setting').isEnabled()) await page.selectOption('#setting',mode);
        assert.equal(await page.locator('#rows tr').count(),5);
        assert.ok(!(await page.locator('#rows').innerText()).match(/NaN|undefined/));
      }
    }
  }
  await page.selectOption('#camera','viofo-a229-pro');
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
  await page.route('**/cameras.json', route => route.fulfill({status:503,body:'unavailable'}));
  await page.goto(url);
  await page.locator('#loading').waitFor({state:'visible'});
  await page.waitForFunction(()=>document.querySelector('#loading').textContent.includes('couldn’t load'));
  assert.equal(await page.locator('#form').isHidden(),true);
  assert.deepEqual(errors, []);
  console.log('Browser checks passed: 31 cameras, 1/2/3CH chart changes, five card sizes, single-channel controls, ranges, desktop/mobile, iframe resizing, delayed loader, forged-message rejection, multiple embeds, missing-data state; no JS errors.');
} finally {
  await browser.close();
  server.close();
}
