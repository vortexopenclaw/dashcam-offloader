import {recordingRows, rowLabel} from './calculator.mjs';
const $ = id => document.getElementById(id);
const roles = {front:'Front', rear:'Rear', left:'Left', right:'Right', interior:'Cabin', telephoto:'Telephoto', interior_front:'Front cabin', interior_rear:'Rear cabin', panoramic_front:'360° camera'};
const collator = new Intl.Collator('en', {numeric:true, sensitivity:'base'});
let cameras = [], current, sourceUrl, cardLinks = [];
function setupLabel(setup) {
  const labels = setup.roles.length === 4 && setup.roles.includes('interior_front') && setup.roles.includes('interior_rear')
    ? ['Front', 'Rear', '2 Cabin'] : setup.roles.map(r=>roles[r]);
  return `${setup.roles.length}CH (${labels.join(' + ')})`;
}
function selectedSetup() { return current.setups.find(s=>s.id === $('channels').value); }
function resolutionLabel(channel) {
  const names = {'3840x2160':'4K', '2560x1440':'2K (1440p)', '1920x1080':'1080p', '1280x720':'720p', '2592x1944':'1944p'};
  return `${names[channel.resolution] || channel.resolution}${channel.fps ? `, ${channel.fps} fps` : ''}`;
}
function fileSizeLabel(channel, mode) {
  // Published whole-system times do not identify each camera's file size.
  if (mode.hours || !Number.isFinite(channel.minMbps)) return '';
  const low = Math.round(channel.minMbps * 7.5), high = Math.round(channel.maxMbps * 7.5);
  return `${mode.sourceType === 'submitted-video' ? 'Video: ' : ''}${low === high ? low : `${low}–${high}`} MB/min`;
}
function renderDetails(setup, mode) {
  $('recording-details').replaceChildren(...setup.roles.map(role=>{
    const channel = mode.channels.find(c=>c.role===role);
    const row = document.createElement('div');row.className='channel-row';
    const name = document.createElement('dt');name.textContent=roles[role];
    const format = document.createElement('dd');format.textContent=resolutionLabel(channel);
    const size = document.createElement('dd');size.textContent=fileSizeLabel(channel,mode);
    row.append(name,format,size);return row;
  }));
}
let photoRequest = 0;
async function renderPhoto(setup) {
  const request = ++photoRequest;
  const photo = current.setupImages?.find(image=>image.setups.includes(setup.id));
  const figure = $('camera-photo'), img = $('product-image');
  if (photo && !figure.hidden && img.getAttribute('src') === photo.path) return;
  figure.hidden = true;
  img.removeAttribute('src');
  if (!photo) return;
  const preload = new Image();
  preload.src = photo.path;
  try { await preload.decode(); } catch { return; }
  if (request !== photoRequest) return;
  img.alt = photo.alt;
  img.src = photo.path;
  figure.hidden = false;
}
function renderLinks(setup) {
  const paragraph=$('shopping-links');paragraph.replaceChildren();
  function link(label,url) {
    const a=document.createElement('a');a.textContent=label;a.href=url;a.target='_blank';a.rel='sponsored noopener';return a;
  }
  const cameraUrl=current.links?.[setup.id];
  const card=cardLinks.find(c=>current.brand===c.brand);
  if(cameraUrl) paragraph.append('You can find the ',link(current.name,cameraUrl),' here.');
  if(card) paragraph.append(cameraUrl ? ' ' : '', 'Looking for a card? Here are ',link(`${current.brand}’s memory cards`,card.url),'.');
  $('shopping').hidden=!cameraUrl && !card;
}
function render() {
  const setup=selectedSetup();
  const mode=setup.modes.find(m=>m.id === $('setting').value);
  $('rows').replaceChildren(...recordingRows(mode).map(row=>{
    const tr=document.createElement('tr');tr.setAttribute('role','row');
    const th=document.createElement('th');th.scope='row';th.setAttribute('role','rowheader');th.textContent=`${row.gb} GB`;
    const td=document.createElement('td');td.setAttribute('role','cell');td.textContent=rowLabel(row);
    tr.append(th,td);return tr;
  }));
  $('chart-caption').textContent=`${current.name}, ${setupLabel(setup)}, ${mode.label}: approximate driving time`;
  $('announcement').textContent=`Chart updated: ${current.name}, ${setupLabel(setup)}, ${mode.label}`;
  renderDetails(setup,mode);
  renderPhoto(setup);
  $('basis').textContent=`${current.name}, ${mode.label}. ${mode.basis}`;
  const submitted=mode.sourceType === 'submitted-video';
  const completeFile=mode.sourceType === 'complete-file';
  const official=Boolean(mode.sourceUrl) && !submitted && !completeFile;
  $('method-detail').textContent=completeFile
    ? 'These estimates use complete recording-file sizes, including audio, metadata and padding. Full-length driving loops are used. Interrupted clips can use more storage per recorded minute.'
    : submitted
    ? 'These estimates use video-stream measurements from submitted camera cards. Complete files may include audio, metadata and reserved padding, so actual recording time can be shorter.'
    : official
    ? 'These estimates use the manufacturer’s published recording times or bitrates for this setting.'
    : 'These estimates come from original video files recorded by the dashcams. I generally test at the highest video quality, although the exact menu setting wasn’t saved for every sample. We add the recording rates of the cameras you select to estimate how much footage fits.';
  if (!mode.hours) $('method-detail').textContent += mode.estimatedMbps != null
    ? ' Each card shows one estimate using the average measured storage rate.'
    : ' Each card shows one estimate using the midpoint recording rate when measurements vary.';
  $('camera-note').textContent=current.note;
  $('camera-note').hidden=!current.note;
  $('source').href=mode.sourceUrl || sourceUrl+'#'+current.sourceAnchor;
  $('source').textContent=completeFile ? 'See the submitted and original-file storage measurements' : submitted ? 'See the submitted recording measurements' : official ? `${current.brand}’s recording data` : 'See the recording measurements';
  $('partition-note').hidden=!current.allocationRequired;
  $('size-note').hidden=!mode.hours && !submitted && !completeFile;
  $('size-note').textContent=mode.notice || (completeFile ? 'Includes file padding, audio and metadata.' : submitted ? 'Video-bitrate estimate. File padding can reduce recording time.' : 'Per-camera file sizes aren’t listed in the manufacturer’s chart.');
  renderLinks(setup);
}
function selectSetup() {
  const previous=$('setting').value;
  const modes=selectedSetup().modes;
  $('setting').replaceChildren(...modes.map(m=>new Option(m.label,m.id)));
  const preferred=modes.find(m=>['maximum','extreme','extreme-h265'].includes(m.id)) || modes[0];
  $('setting').value=modes.some(m=>m.id===previous) ? previous : preferred.id;
  $('setting-control').hidden=modes.length===1;
  $('setting').disabled=modes.length===1;
  render();
}
function selectCamera() {
  const previous=$('channels').value;
  current=cameras.find(c=>c.id === $('camera').value);
  $('channels').replaceChildren(...current.setups.map(s=>new Option(setupLabel(s),s.id)));
  $('channels').value=current.setups.some(s=>s.id===previous) ? previous : current.setups.at(-1).id;
  $('channels').disabled=current.setups.length===1;
  $('setting').replaceChildren();
  selectSetup();
}
function selectBrand(preferredId) {
  const models=cameras.filter(c=>c.brand === $('brand').value).sort((a,b)=>collator.compare(a.model,b.model));
  $('camera').replaceChildren(...models.map(c=>new Option(c.model,c.id)));
  if(models.some(c=>c.id===preferredId)) $('camera').value=preferredId;
  selectCamera();
}
try {
  const response=await fetch(new URL('./cameras.json',import.meta.url));
  if(!response.ok) throw new Error('Chart unavailable');
  const data=await response.json();
  if(data.schemaVersion!==3 || !Array.isArray(data.cameras) || !data.cameras.length) throw new Error('Invalid chart');
  for(const camera of data.cameras) {
    if(!camera.setups?.length || !camera.brand || !camera.model) throw new Error('Missing model');
    camera.setups.forEach(setup=>{if(!setup.modes?.length) throw new Error('Missing settings');setup.modes.forEach(recordingRows);});
  }
  cameras=data.cameras;sourceUrl=data.sourceUrl;cardLinks=data.cardLinks || [];
  const brands=[...new Set(cameras.map(c=>c.brand))].sort(collator.compare);
  $('brand').replaceChildren(...brands.map(b=>new Option(b,b)));
  const initial=cameras.find(c=>c.id==='viofo-a229-pro') || cameras[0];
  $('brand').value=initial.brand;
  $('brand').addEventListener('change',()=>selectBrand());
  $('camera').addEventListener('change',selectCamera);
  $('channels').addEventListener('change',selectSetup);
  $('setting').addEventListener('change',render);
  $('form').addEventListener('submit',event=>event.preventDefault());
  selectBrand(initial.id);$('loading').hidden=true;$('form').hidden=false;
} catch {
  $('form').hidden=true;$('loading').hidden=false;
  $('loading').textContent='The recording-time chart couldn’t load. Please reload the page to try again.';
}
const embedOrigin=(()=>{try{return new URL(document.referrer).origin;}catch{return null;}})();
if(parent!==window && embedOrigin) {
  const measure=()=>parent.postMessage({type:'vr-recording-height',height:Math.ceil(document.documentElement.getBoundingClientRect().height)},embedOrigin);
  new ResizeObserver(measure).observe(document.documentElement);
  window.addEventListener('message',event=>{
    if(event.source===parent && event.origin===embedOrigin && event.data?.type==='vr-recording-measure') measure();
  });
}
