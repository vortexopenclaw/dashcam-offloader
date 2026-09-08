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
  assert.match(await page.locator('#result').innerText(), /7 hr 9 min/);
  await page.screenshot({path:path.join(evidence,'desktop.png'),fullPage:true});
  await page.selectOption('#camera','thinkware-u3000-pro');
  assert.equal(await page.locator('#result').innerText(), 'Check storage settings');
  await page.fill('#allocation','50');
  assert.match(await page.locator('#result').innerText(), /6 hr 45 min/);
  await page.selectOption('#direction','capacity');
  assert.equal(await page.locator('#result').innerText(), 'About 304 GB');
  await page.fill('#allocation','0');
  assert.equal(await page.locator('#result').innerText(), 'Check storage settings');
  await page.selectOption('#camera','viofo-a329s');
  assert.match(await page.locator('#result').innerText(), /351–400 GB/);
  await page.selectOption('#camera','custom');
  await page.fill('#bitrate','80');
  assert.equal(await page.locator('#result').innerText(), 'About 304 GB');
  await page.fill('#bitrate','');
  assert.equal(await page.locator('#result').innerText(), 'Check storage settings');
  await page.selectOption('#camera','viofo-a229-pro');
  await page.selectOption('#direction','time');
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
  await page.locator('#form').waitFor({state:'visible'});
  assert.match(await page.locator('#loading').innerText(), /custom total bitrate/);
  assert.match(await page.locator('#result').innerText(), /9 hr 0 min/);
  assert.deepEqual(errors, []);
  console.log('Browser checks passed: desktop, mobile, inverse, partitions, ranges, custom, invalid inputs, iframe resizing, delayed WordPress loader, forged resize rejection, multiple embeds, missing-data fallback; no JS errors.');
} finally {
  await browser.close();
  server.close();
}
