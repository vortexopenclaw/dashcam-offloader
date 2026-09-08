import {calculate, rates, hoursLabel} from './calculator.mjs';
const $ = id => document.getElementById(id);
let cameras = [];
let current;
function number(id) { return $(id).value.trim() === '' ? NaN : Number($(id).value); }
function update() {
  const capacity = $('direction').value === 'capacity';
  $('card-field').hidden = capacity;
  $('hours-field').hidden = !capacity;
  $('allocation-field').hidden = !$('partitioned').checked;
  $('result-title').textContent = capacity ? 'Estimated card space needed' : 'Estimated driving footage';
  $('result').classList.remove('error');
  try {
    const rate = current ? rates(current) : {minMbps: number('bitrate'), maxMbps: number('bitrate')};
    const result = calculate({...rate, allocationPercent: $('partitioned').checked ? number('allocation') : 100,
      reservePercent: number('reserve'), ...(capacity ? {targetHours: number('hours')} : {cardGB: number('card')})});
    if (capacity) {
      $('result').textContent = result.minGB === result.maxGB ? `About ${Math.ceil(result.maxGB)} GB` : `${Math.ceil(result.minGB)}–${Math.ceil(result.maxGB)} GB`;
    } else {
      $('result').textContent = result.minHours === result.maxHours ? `About ${hoursLabel(result.minHours)}` : `${hoursLabel(result.minHours)} – ${hoursLabel(result.maxHours)}`;
    }
    $('result-note').textContent = `${rate.minMbps.toFixed(1)}${rate.maxMbps === rate.minMbps ? '' : '–' + rate.maxMbps.toFixed(1)} Mbps total · ${$('partitioned').checked ? number('allocation') : 100}% driving allocation · ${number('reserve')}% headroom. ` +
      (capacity ? 'Choose a supported card with at least this capacity; compatibility is not verified.' : 'Driving-only estimate. Parking and protected files sharing this space can shorten retention.');
  } catch (error) {
    $('result').textContent = 'Check storage settings';
    $('result').classList.add('error');
    $('result-note').textContent = error.message;
  }
}
function selectCamera() {
  current = cameras.find(camera => camera.id === $('camera').value);
  $('manual-fields').hidden = Boolean(current);
  $('partitioned').checked = current?.allocationRequired ?? false;
  $('partitioned').disabled = current?.allocationRequired ?? false;
  $('allocation').value = '';
  $('preset-note').textContent = current ? `Measured ${current.channels.length}-channel sample: ` + current.channels.map(c => `${c.role} ${c.resolution} / ${c.fps} fps / ${c.codec}`).join('; ') + '. Quality setting and firmware were not recorded consistently. Match this configuration, or use a custom bitrate.' : 'Enter the combined bitrate of every channel recording at the same time.';
  $('source').hash = current?.sourceAnchor ?? '';
  update();
}
try {
  const response = await fetch(new URL('./cameras.json', import.meta.url));
  if (!response.ok) throw new Error('Presets unavailable');
  const data = await response.json();
  if (data.schemaVersion !== 1 || !Array.isArray(data.cameras) || !data.cameras.length) throw new Error('Invalid presets');
  cameras = data.cameras;
  for (const camera of cameras) $('camera').add(new Option(camera.name, camera.id));
  $('camera').add(new Option('Other camera / custom bitrate', 'custom'));
  $('camera').value = cameras.some(c => c.id === 'viofo-a229-pro') ? 'viofo-a229-pro' : cameras[0].id;
  $('loading').hidden = true;
  $('form').hidden = false;
  $('camera').addEventListener('change', selectCamera);
  $('form').addEventListener('submit', event => event.preventDefault());
  $('form').addEventListener('input', update);
  selectCamera();
} catch {
  $('loading').textContent = 'Camera presets could not load. You can still calculate with a custom total bitrate.';
  $('camera').add(new Option('Custom bitrate', 'custom'));
  $('form').hidden = false;
  $('form').addEventListener('submit', event => event.preventDefault());
  $('form').addEventListener('input', update);
  selectCamera();
}
// Send dimensions only to the embedding page, never camera selections or inputs.
const embedOrigin = (() => { try { return new URL(document.referrer).origin; } catch { return null; } })();
if (parent !== window && embedOrigin) {
  const measure = () => parent.postMessage({type:'vr-recording-height', height:Math.ceil(document.documentElement.getBoundingClientRect().height)}, embedOrigin);
  new ResizeObserver(measure).observe(document.documentElement);
  window.addEventListener('message', event => {
    if (event.source === parent && event.origin === embedOrigin && event.data?.type === 'vr-recording-measure') measure();
  });
}
