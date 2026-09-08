import {recordingRows, rowLabel} from './calculator.mjs';
const $ = id => document.getElementById(id);
const roles = {front:'front', rear:'rear', interior:'cabin', telephoto:'telephoto'};
let cameras = [], current, sourceUrl, cardLinks = [];
function setupLabel(setup) { return `${setup.roles.length}CH · ${setup.roles.map(r=>roles[r]).join(' + ')}`; }
function selectedSetup() { return current.setups.find(s=>s.id === $('channels').value); }
function resolutionLabel(channel) {
  const names = {'3840x2160':'4K', '2560x1440':'2K (1440p)', '1920x1080':'1080p', '1280x720':'720p'};
  return `${roles[channel.role]}: ${names[channel.resolution] || channel.resolution} · ${channel.fps} fps`;
}
function render() {
  const setup = selectedSetup();
  const mode = setup.modes.find(m=>m.id === $('setting').value);
  $('rows').replaceChildren(...recordingRows(mode).map(row => {
    const tr = document.createElement('tr');
    const th = document.createElement('th'); th.scope='row'; th.textContent=`${row.gb} GB`;
    const td = document.createElement('td'); td.textContent=rowLabel(row);
    tr.append(th,td); return tr;
  }));
  $('chart-caption').textContent = `${current.name}, ${setupLabel(setup)}, ${mode.label}: approximate driving time`;
  $('announcement').textContent = `Chart updated: ${current.name}, ${setupLabel(setup)}, ${mode.label}`;
  $('recording-details').textContent = setup.roles.map(role=>resolutionLabel(mode.channels.find(c=>c.role===role))).join(' • ');
  $('basis').textContent = `${current.name} · ${setupLabel(setup)} · ${mode.label}. ${mode.basis}`;
  const official = Boolean(mode.sourceUrl);
  $('method-detail').textContent = official
    ? 'These figures come from the manufacturer’s published recording-time or bitrate data for this setting, not our own measurements. Different settings are shown only where we have supporting data.'
    : 'We inspected original video files recorded by the dashcams themselves and used their recording rates to estimate storage needs. We add the rates for the cameras you select. Reduced-channel combinations assume those rates stay the same. The saved samples do not always identify the quality menu setting, so we do not label them Normal or Maximum without confirmation.';
  $('setting-note').textContent = setup.modes.length === 1
    ? 'Only this recording setting has verified data here; other camera settings may be available.'
    : 'Choose a setting to update the times. Only settings with supporting data are listed.';
  $('camera-note').textContent = current.note;
  $('camera-note').hidden = !current.note;
  $('source').href = mode.sourceUrl || sourceUrl + '#' + current.sourceAnchor;
  $('source').textContent = official ? `${current.name.split(' ')[0]} recording reference` : 'View our recording measurements';
  $('partition-note').hidden = !current.allocationRequired;
  const links = [];
  function link(label,url) {
    const a=document.createElement('a');a.textContent=label;a.href=url;a.target='_blank';a.rel='sponsored noopener';links.push(a);
  }
  if (current.links?.[setup.id]) link(`Shop ${current.name} · ${setup.roles.length}CH`,current.links[setup.id]);
  const card = cardLinks.find(c=>current.name.startsWith(c.brand+' '));
  if (card) link(card.label,card.url);
  $('shopping-links').replaceChildren(...links);
  $('shopping').hidden = links.length === 0;
}
function selectSetup() {
  const previous = $('setting').value;
  const modes = selectedSetup().modes;
  $('setting').replaceChildren(...modes.map(m=>new Option(m.label,m.id)));
  $('setting').value = modes.some(m=>m.id===previous) ? previous : modes[0].id;
  $('setting').disabled = modes.length === 1;
  render();
}
function selectCamera() {
  const previous = $('channels').value;
  current = cameras.find(c=>c.id === $('camera').value);
  $('channels').replaceChildren(...current.setups.map(s=>new Option(setupLabel(s),s.id)));
  $('channels').value = current.setups.some(s=>s.id===previous) ? previous : current.setups.at(-1).id;
  $('channels').disabled = current.setups.length === 1;
  // Do not carry a quality label across brands: 'maximum' can mean different things.
  $('setting').replaceChildren();
  selectSetup();
}
try {
  const response = await fetch(new URL('./cameras.json', import.meta.url));
  if (!response.ok) throw new Error('Chart unavailable');
  const data = await response.json();
  if (data.schemaVersion !== 3 || !Array.isArray(data.cameras) || !data.cameras.length) throw new Error('Invalid chart');
  for (const camera of data.cameras) {
    if (!camera.setups?.length) throw new Error('Missing setups');
    camera.setups.forEach(setup => { if (!setup.modes?.length) throw new Error('Missing settings'); setup.modes.forEach(recordingRows); });
  }
  cameras = data.cameras; sourceUrl = data.sourceUrl; cardLinks = data.cardLinks || [];
  for (const camera of cameras) $('camera').add(new Option(camera.name,camera.id));
  $('camera').value = cameras.some(c=>c.id==='viofo-a229-pro') ? 'viofo-a229-pro' : cameras[0].id;
  $('camera').addEventListener('change',selectCamera);
  $('channels').addEventListener('change',selectSetup);
  $('setting').addEventListener('change',render);
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
