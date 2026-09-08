import {recordingRows, rowLabel} from './calculator.mjs';
const $ = id => document.getElementById(id);
const roles = {front:'front', rear:'rear', interior:'cabin', telephoto:'telephoto'};
let cameras = [], current, sourceUrl;
function setupLabel(setup) { return `${setup.roles.length}CH · ${setup.roles.map(r=>roles[r]).join(' + ')}`; }
function render() {
  const setup = current.setups.find(s=>s.id === $('channels').value);
  $('rows').replaceChildren(...recordingRows(setup).map(row => {
    const tr = document.createElement('tr');
    const th = document.createElement('th'); th.scope='row'; th.textContent=`${row.gb} GB`;
    const td = document.createElement('td'); td.textContent=rowLabel(row);
    tr.append(th,td); return tr;
  }));
  $('chart-caption').textContent = `${current.name}, ${setupLabel(setup)}: approximate driving time`;
  $('announcement').textContent = `Chart updated: ${current.name}, ${setupLabel(setup)}`;
  $('basis').textContent = setup.basis + '.';
  $('source').href = setup.sourceUrl || sourceUrl + '#' + current.sourceAnchor;
  $('source').textContent = setup.sourceUrl ? 'VIOFO recording-time chart' : 'Offloader measurement reference';
  $('partition-note').hidden = !current.allocationRequired;
}
function selectCamera() {
  const previous = $('channels').value;
  current = cameras.find(c=>c.id === $('camera').value);
  $('channels').replaceChildren(...current.setups.map(s=>new Option(setupLabel(s),s.id)));
  $('channels').value = current.setups.some(s=>s.id===previous) ? previous : current.setups.at(-1).id;
  $('channels').disabled = current.setups.length === 1;
  render();
}
try {
  const response = await fetch(new URL('./cameras.json', import.meta.url));
  if (!response.ok) throw new Error('Chart unavailable');
  const data = await response.json();
  if (data.schemaVersion !== 2 || !Array.isArray(data.cameras) || !data.cameras.length) throw new Error('Invalid chart');
  for (const camera of data.cameras) {
    if (!camera.setups?.length) throw new Error('Missing setups');
    camera.setups.forEach(recordingRows);
  }
  cameras = data.cameras; sourceUrl = data.sourceUrl;
  for (const camera of cameras) $('camera').add(new Option(camera.name,camera.id));
  $('camera').value = cameras.some(c=>c.id==='viofo-a229-pro') ? 'viofo-a229-pro' : cameras[0].id;
  $('camera').addEventListener('change',selectCamera);
  $('channels').addEventListener('change',render);
  $('form').addEventListener('submit',event=>event.preventDefault());
  selectCamera(); $('loading').hidden=true; $('form').hidden=false;
} catch {
  $('form').hidden=true; $('loading').hidden=false;
  $('loading').textContent='The recording-time chart couldn’t load. Please reload the page to try again.';
}
const embedOrigin = (()=>{try{return new URL(document.referrer).origin;}catch{return null;}})();
if (parent !== window && embedOrigin) {
  const measure = ()=>parent.postMessage({type:'vr-recording-height',height:Math.ceil(document.documentElement.getBoundingClientRect().height)},embedOrigin);
  new ResizeObserver(measure).observe(document.documentElement);
  window.addEventListener('message',event=>{
    if(event.source===parent && event.origin===embedOrigin && event.data?.type==='vr-recording-measure') measure();
  });
}
