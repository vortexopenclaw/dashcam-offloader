// Shared generic private discovery v1 vocabulary. No catalog/identity promotion.
const groups = {
  manufacturer: ['manufacturer','make','vendor','brand'],
  model: ['model','model_name','camera_model','device_model','product_model','dev_model','rear_model','inside_model','front_model','rc_model'],
  firmware: ['firmware','firmware_version','fw_version','fw','soft_version','software_version','rear_version','inside_version','micom_version'],
  build: ['build','build_version','version','hardware_version'],
  setting: ['resolution','width','height','fps','frame_rate','bitrate','quality','hdr','parking_mode','time_lapse','codec'],
};
const counts = ['inventoriedCandidates','inspectedFiles','uninspectedFiles','retainedObservations','omittedObservations','bytesRead'];
const reasons = ['file_limit','byte_limit','oversize','unsupported_format','invalid_encoding','malformed','unsafe_value','read_error','changed_source','observation_limit'];
const formats = ['json','ini','key_value','xml','framed_json','binary','tar','jpeg','isobmff','unknown'];
const encodings = ['utf8','utf16le','utf16be','binary','unknown'];
const integer = n => Number.isSafeInteger(n) && n >= 0;
const object = x => x && typeof x === 'object' && !Array.isArray(x);
const exact = (x, keys) => object(x) && Object.keys(x).length === keys.length && keys.every(k => Object.hasOwn(x,k));
export function safeDiscoveryValue(value, key) {
  if (typeof value !== 'string' || !value.length || value.length > 80 || !/^[A-Za-z0-9][A-Za-z0-9 _().+\-]*$/.test(value) || value.trim() !== value ||
      /password|passwd|secret|token|ssid|wifi|serial|latitude|longitude|address|credential|canary|https?|email|\bGPS\b/i.test(value) ||
      /\b(?:192\.168|10\.[0-9]{1,3}|172\.(?:1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}\b/.test(value)) return false;
  const field = Object.keys(groups).find(f => groups[f].includes(key));
  if (field === 'model' || field === 'manufacturer') return value.length <= 64 && value.split(/ +/).length <= 6 && /[A-Za-z]/.test(value) && !/[0-9]{9,}/.test(value);
  if (field === 'firmware' || field === 'build') return /^[vV]?[0-9]{1,4}(?:\.[0-9]{1,6}){1,5}(?:[_+\-][A-Za-z0-9.\-]{1,24})?$/.test(value);
  if (field !== 'setting') return false;
  const enums = {codec:['h264','h265','hevc','avc','mjpeg'],quality:['low','medium','high','fine','normal','superfine'],hdr:['on','off','auto','0','1'],parking_mode:['on','off','auto','low_bitrate','time_lapse','motion','collision'],time_lapse:['on','off','0','1']};
  if (enums[key]) return enums[key].includes(value.toLowerCase());
  return (key === 'resolution' ? /^[1-9][0-9]{1,4}[xX][1-9][0-9]{1,4}$/ : /^[0-9]{1,9}(?:\.[0-9]{1,3})?$/).test(value);
}
export function validDiscovery(d) {
  if (d === undefined) return true; // Legacy envelopes omit the optional field.
  if (!exact(d,['version','sources','observations','coverage']) || d.version !== 1 || !Array.isArray(d.sources) || d.sources.length > 128 || !Array.isArray(d.observations) || d.observations.length > 128) return false;
  const ids = new Set();
  for (const s of d.sources) {
    if (!exact(s,['id','format','encoding','sizeBytes']) || typeof s.id !== 'string' || !/^support-[1-9][0-9]{0,2}$/.test(s.id) || Number(s.id.slice(8)) > 256 || ids.has(s.id) || !formats.includes(s.format) || !encodings.includes(s.encoding) || !integer(s.sizeBytes) || s.sizeBytes > 65536) return false;
    ids.add(s.id);
  }
  for (const o of d.observations) {
    if (!exact(o,['sourceId','field','key','value','line','record','scope']) || !ids.has(o.sourceId) || !Object.hasOwn(groups,o.field) || !groups[o.field].includes(o.key) || !safeDiscoveryValue(o.value,o.key) || !integer(o.line) || o.line < 1 || !integer(o.record) || o.scope !== 'unbound') return false;
  }
  const c = d.coverage;
  if (!exact(c,[...counts,'limited','multipleModelValues','reasons']) || !counts.every(k=>integer(c[k])) || typeof c.limited !== 'boolean' || typeof c.multipleModelValues !== 'boolean' || !object(c.reasons) || Object.entries(c.reasons).some(([k,v])=>!reasons.includes(k)||!integer(v))) return false;
  if (c.inspectedFiles > 256 || c.bytesRead > 4194304 || c.inspectedFiles + c.uninspectedFiles !== c.inventoriedCandidates || c.retainedObservations !== d.observations.length || d.sources.length > c.inspectedFiles || (c.omittedObservations > 0 || Object.values(c.reasons).some(v=>v>0)) && !c.limited) return false;
  const models = new Set(d.observations.filter(o=>o.field==='model').map(o=>o.value.toLowerCase()));
  return models.size <= 1 || c.multipleModelValues;
}
export function projectDiscovery(d) {
  if (!d || !validDiscovery(d)) return undefined;
  return {version:1,sources:d.sources.map(s=>({id:s.id,format:s.format,encoding:s.encoding,sizeBytes:s.sizeBytes})),
    observations:d.observations.map(o=>({sourceId:o.sourceId,field:o.field,key:o.key,value:o.value,line:o.line,record:o.record,scope:'unbound'})),
    coverage:Object.fromEntries([...counts,'limited','multipleModelValues','reasons'].map(k=>[k,k==='reasons'?{...d.coverage.reasons}:d.coverage[k]]))};
}
