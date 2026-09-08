// Read-only, browser-local preview. Never saves a post or uploads site files.
// node theme-preview.mjs <playwright module> <CDP URL> <staging article URL>
import {readFile, mkdir, writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const {chromium} = await import(process.argv[2]);
const articleUrl = new URL(process.argv[4]);
const root = fileURLToPath(new URL('./dist/', import.meta.url));
const evidence = fileURLToPath(new URL('./evidence/', import.meta.url));
await mkdir(evidence, {recursive:true});
const browser = await chromium.connectOverCDP(process.argv[3]);
const page = await browser.contexts()[0].newPage();
const prefix = '/__vr_calculator_preview__/';
const assets = new Set(['index.html','widget.mjs','calculator.mjs','style.css','embed.js','cameras.json']);
const checks = [];
const errors = [];
page.on('pageerror', error => errors.push(error.message));
try {
  await page.route(articleUrl.origin + prefix + '**', async route => {
    const name = new URL(route.request().url()).pathname.slice(prefix.length);
    if (!assets.has(name)) return route.abort();
    await route.fulfill({status:200, contentType:({'.html':'text/html','.mjs':'text/javascript','.js':'text/javascript','.css':'text/css','.json':'application/json'})[path.extname(name)],body:await readFile(path.join(root,name))});
  });
  const response = await page.goto(articleUrl.href,{waitUntil:'domcontentloaded',timeout:30000});
  if (response.status() !== 200 || new URL(page.url()).origin !== articleUrl.origin) throw new Error('Staging article did not load');
  await page.locator('.entry-content').first().waitFor();
  await page.setViewportSize({width:1440,height:1100});
  await page.screenshot({path:path.join(evidence,'staging-theme-before.png'),fullPage:false});
  await page.evaluate(prefix => {
    const content = document.querySelector('.entry-content');
    const heading = document.querySelector('h1');
    if (heading) heading.textContent = 'Dashcam Recording Time Chart';
    document.title = 'Simplified recording-time chart (browser preview)';
    content.replaceChildren();
    const notice = document.createElement('p');
    notice.textContent = 'BROWSER-ONLY PREVIEW: This calculator has not been installed or saved to staging.';
    notice.style.cssText = 'padding:12px;background:#fff3cd;color:#513f03;';
    const intro = document.createElement('p');
    intro.textContent = 'Choose your dashcam and channel setup to compare recording times across memory card sizes.';
    const frame = document.createElement('iframe');
    frame.dataset.vrRecordingTime = '';
    frame.src = prefix + 'index.html';
    frame.title = 'Dashcam recording time calculator';
    frame.style.cssText = 'display:block;width:100%;height:1100px;border:0;max-width:100%;';
    const after = document.createElement('p');
    after.id = 'vr-after-calculator';
    after.textContent = 'These are driving-only estimates. Parking footage and protected recordings can reduce the driving history retained on the card.';
    content.append(notice,intro,frame,after);
    const loader = document.createElement('script');
    loader.src = prefix + 'embed.js';
    document.body.append(loader);
  },prefix);
  const frame = page.frameLocator('iframe[data-vr-recording-time]');
  await frame.locator('#form').waitFor({state:'visible'});
  await page.waitForFunction(() => document.querySelector('iframe[data-vr-recording-time]').style.height !== '1100px');
  for (const width of [1440,768,375]) {
    await page.setViewportSize({width,height:1000});
    await page.waitForTimeout(250);
    const geometry = await page.evaluate(() => {
      const frame = document.querySelector('iframe[data-vr-recording-time]');
      const rect = frame.getBoundingClientRect();
      const content = document.querySelector('.entry-content').getBoundingClientRect();
      const next = document.querySelector('#vr-after-calculator').getBoundingClientRect();
      return {viewport:innerWidth,pageOverflow:document.documentElement.scrollWidth > innerWidth,
        frameWidth:rect.width,contentWidth:content.width,gapAfter:next.top-rect.bottom};
    });
    const innerOverflow = await frame.locator('html').evaluate(el=>el.scrollWidth > innerWidth);
    if (geometry.frameWidth > geometry.contentWidth+1 || innerOverflow || geometry.gapAfter < -1) throw new Error('Calculator layout failed');
    checks.push({...geometry,innerOverflow});
    await page.locator('iframe[data-vr-recording-time]').scrollIntoViewIfNeeded();
    await page.screenshot({path:path.join(evidence,`staging-theme-${width}.png`),fullPage:false});
  }
  await frame.locator('#camera').selectOption('viofo-a229-pro');
  await frame.locator('#channels').selectOption('front-rear');
  if (!(await frame.locator('#rows').innerText()).includes('10 hr 30 min')) throw new Error('2CH chart incorrect');
  await frame.locator('#channels').selectOption('front-rear-interior');
  if (!(await frame.locator('#rows').innerText()).includes('8 hr 30 min')) throw new Error('3CH chart incorrect');
  await frame.locator('.method summary').click();
  await page.waitForTimeout(250);
  const clipped = await page.locator('iframe[data-vr-recording-time]').evaluate(el=>el.clientHeight < el.contentDocument.documentElement.scrollHeight);
  if (clipped) throw new Error('Expanded methodology clipped');
  await frame.locator('.method summary').click();
  await page.setViewportSize({width:1280,height:1000});
  await page.locator('.entry-content').first().scrollIntoViewIfNeeded();
  const result = {browserOnly:true,siteWrites:false,checks,calculatorChecks:'2CH/3CH charts and expansion passed',pageErrors:errors};
  await writeFile(path.join(evidence,'staging-theme-checks.json'),JSON.stringify(result,null,2));
  console.log(JSON.stringify(result));
} finally {
  await browser.close();
}
