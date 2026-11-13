import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import worker,{sanitizeScan,validateFeedback} from './worker.js';
import {validDiscovery,projectDiscovery,safeDiscoveryValue} from './discovery.js';
const discovery = () => ({version:1,sources:[{id:'support-1',format:'json',encoding:'utf8',sizeBytes:120}],observations:[
  {sourceId:'support-1',field:'model',key:'model',value:'NovaCam QX7',line:1,record:0,scope:'unbound'},
  {sourceId:'support-1',field:'firmware',key:'soft_version',value:'8.0.0.16',line:1,record:0,scope:'unbound'}],
  coverage:{inventoriedCandidates:1,inspectedFiles:1,uninspectedFiles:0,retainedObservations:2,omittedObservations:0,bytesRead:120,limited:false,multipleModelValues:false,reasons:{}}});
const envelope = d => ({kind:'bug',message:'Synthetic generic discovery',scan:{discovery:d}});
async function store(body) {
  const records=new Map();
  const env={RATE_LIMIT_SALT:'synthetic-fixture-only-not-a-secret'.repeat(2),
    FEEDBACK_RATE_LIMITER:{idFromName:n=>n,get:()=>({fetch:async()=>Response.json({ok:true})})},
    FEEDBACK_KV:{put:async(k,v)=>{assert.equal(records.has(k),false);records.set(k,v);},get:async k=>records.get(k)}};
  const response=await worker.fetch(new Request('https://example.test/feedback',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}),env);
  assert.equal(response.status,202);
  const receipt=await response.json();
  const key=[...records.keys()].find(k=>k.includes(receipt.id));
  assert.ok(key);
  const stored=JSON.parse(await env.FEEDBACK_KV.get(key));
  assert.equal(stored.id,receipt.id);
  return stored;
}
test('generic declarations survive HTTP handler and exact KV readback without recognition or owner overwrite',async()=>{
  const d=discovery(), body=envelope(d);
  body.training={manufacturer:'Owner entry',model:'Owner model',channelSetup:'Unknown',notes:''};
  assert.equal(validateFeedback(body).ok,true);
  const stored=await store(body);
  assert.deepEqual(stored.scan.discovery,d);
  assert.deepEqual(stored.training,body.training);
  assert.equal(stored.scan.identifiedCamera,null);
});
test('legacy optional discovery and coverage-only unsupported records survive',async()=>{
  assert.equal(validDiscovery(undefined),true);
  assert.equal(validateFeedback({kind:'bug',message:'Legacy',scan:{}}).ok,true);
  const d=discovery();d.sources[0].format='xml';d.observations=[];
  Object.assign(d.coverage,{retainedObservations:0,limited:true,reasons:{unsupported_format:1}});
  assert.deepEqual((await store(envelope(d))).scan.discovery,d);
  assert.deepEqual(projectDiscovery(d),d);
});
test('explicit schema rejects paths, arbitrary keys, extra raw text, unsafe values and dangling aliases',()=>{
  const changes=[
    d=>d.sources[0].id='private/settings.json',d=>d.sources[0].path='private-canary',d=>d.sources[0].format='decoded_archive',
    d=>d.sources[0].sizeBytes=65537,d=>d.sources.push({...d.sources[0]}),d=>d.sources=Array(129).fill(d.sources[0]),
    d=>d.observations[0].sourceId='support-2',d=>d.observations[0].key='wifi_pwd',d=>d.observations[0].scope='main',
    d=>d.observations[0].field='identity',d=>d.observations[0].value='https://private.invalid',d=>d.observations[0].value='NEVER-UPLOAD-CANARY',
    d=>{d.sources[0].format='ini';d.observations[0].line=0;},d=>d.observations[0].record=-1,d=>d.observations[0].rawLine='canary',
    d=>d.observations[1].field='build',d=>d.observations=Array(129).fill(d.observations[0]),
    d=>d.coverage.reasons={privatePath:1},d=>d.coverage.reasons={unsafe_value:1},d=>d.coverage.retainedObservations=1,
    d=>d.coverage.bytesRead=4194305,d=>d.coverage.inspectedFiles=257,d=>d.coverage.uninspectedFiles=2,
    d=>d.coverage.omittedObservations=1,d=>d.coverage.limited='false',d=>d.version=2,
  ];
  for(const change of changes){const d=discovery();change(d);assert.equal(validateFeedback(envelope(d)).error,'invalid_discovery',change.toString());}
  for(const d of [null,[],{},'canary'])assert.equal(validDiscovery(d),false);
});
test('technical validators are field-specific rather than printable-fragment redaction',()=>{
  for(const [key,value] of [['model','OtherCamera RX9'],['firmware','v9.0.0.17'],['version','1.2'],['resolution','3840x2160'],['fps','29.97'],['codec','HEVC'],['parking_mode','time-lapse']])assert.equal(safeDiscoveryValue(value,key),true,`${key}=${value}`);
  for(const [key,value] of [['model','person@example.com'],['model','192\u002E168\u002E1\u002E1'],['model','123456789012'],['firmware','Owner said update'],['codec','arbitrary words'],['hdr','download'],['unknown','QX7'],['fps','29.97 location'],['model','AX1\n']])assert.equal(safeDiscoveryValue(value,key),false,`${key}=${value}`);
});
test('multiple models cannot be hidden by inconsistent flags; sticky conflict survives truncation',()=>{
  const d=discovery();d.observations.push({...d.observations[0],value:'Other B2'});d.coverage.retainedObservations++;
  assert.equal(validDiscovery(d),false);d.coverage.multipleModelValues=true;assert.equal(validDiscovery(d),true);
  d.observations.pop();d.coverage.retainedObservations--;d.coverage.omittedObservations=30;d.coverage.limited=true;d.coverage.reasons.observation_limit=30;
  assert.equal(validDiscovery(d),true);assert.equal(sanitizeScan({discovery:d}).discovery.coverage.multipleModelValues,true);
});
const nativeRoot=process.env.DASHCAM_NATIVE_EVIDENCE_OUTPUT;
test('native unknown-file scan -> reviewed snapshot -> HTTP -> KV exact stored record and anonymous omission',{skip:!nativeRoot},async()=>{
  for(const label of ['generic','generic-coverage']){
    const body=JSON.parse(readFileSync(`${nativeRoot}/${label}-private.json`,'utf8'));
    assert.equal(validateFeedback(body).ok,true,JSON.stringify(body.scan.discovery));
    const stored=await store(body);
    assert.deepEqual(stored.scan.discovery,body.scan.discovery);
    writeFileSync(`${nativeRoot}/${label}-stored.json`,JSON.stringify(stored),{flag:'wx'});
    if(label==='generic'){
      assert.ok(stored.scan.discovery.observations.some(o=>o.value==='NovaCam QX7'));
      assert.ok(stored.scan.discovery.coverage.multipleModelValues);
      assert.equal(JSON.stringify(stored.scan.discovery).includes('CANARY'),false);
    } else assert.equal(stored.scan.discovery.observations.length,0);
  }
  const anonymous=JSON.parse(readFileSync(`${nativeRoot}/generic-public.json`,'utf8'));
  function absent(value){if(Array.isArray(value))value.forEach(absent);else if(value&&typeof value==='object'){assert.equal(Object.hasOwn(value,'discovery'),false);Object.values(value).forEach(absent);}}
  absent(anonymous);
  for(const privateToken of ['support-','NovaCam QX7','StarView S8','settings.weird'])assert.equal(JSON.stringify(anonymous).includes(privateToken),false);
});
