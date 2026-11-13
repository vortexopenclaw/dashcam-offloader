import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync} from 'node:fs';
import worker, {sanitizeScan, validateFeedback} from './worker.js';
import {ddpaiModels, recognizedDDPAIModel} from './ddpai-models.js';

const fixture = JSON.parse(readFileSync(new URL('./ddpai-device-info.fixture.json', import.meta.url), 'utf8'));
const sourceFile = 'DCIM/207log/ui/ui_20300101120000_000.log';
const entries = [
  {manufacturer:'DDPAI',component:'logging_device',reportedModel:fixture.model,model:'Z100 Master',firmwareVersion:fixture.soft_version,
    sourceKind:'ddpai_ui_device_info',sourceFile,sourceLine:29,identityEstablished:true},
  ...['rear','inside'].map(component => ({manufacturer:'DDPAI',component,reportedModel:null,model:null,
    firmwareVersion:fixture[`${component}_version`],sourceKind:'ddpai_ui_device_info',sourceFile,sourceLine:29,identityEstablished:false}))
];
const coverage = {inspectedFiles:1,retainedEntries:3,omittedEntries:0,limited:false};
const payload = () => ({kind:'bug',message:'Synthetic metadata regression',scan:{componentMetadata:structuredClone(entries),componentMetadataCoverage:{...coverage}}});
async function store(body) {
  const records = new Map();
  const env = {RATE_LIMIT_SALT:'synthetic-fixture-only-not-a-secret'.repeat(2),
    FEEDBACK_RATE_LIMITER:{idFromName:name=>name,get:()=>({fetch:async()=>Response.json({ok:true})})},
    FEEDBACK_KV:{put:async(key,value)=>{assert.equal(records.has(key),false);records.set(key,value);},get:async key=>records.get(key)}};
  const response = await worker.fetch(new Request('https://example.test/feedback', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}),env);
  assert.equal(response.status,202);
  const receipt = await response.json();
  const [key] = [...records.keys()];
  assert.ok(key.includes(receipt.id));
  const record = JSON.parse(await env.FEEDBACK_KV.get(key));
  assert.equal(record.id,receipt.id);
  return record;
}

test('allowlisted actual sanitized device-info survives actual HTTP -> exact mock KV receipt readback', async()=>{
  const body = payload();
  Object.assign(body.scan.componentMetadata[0], {wifi_pwd:'must-not-retain',sn_code:'must-not-retain',rawLine:'must-not-retain',gps:'must-not-retain'});
  Object.assign(body.scan.componentMetadataCoverage,{rawLog:'must-not-retain'});
  assert.equal(validateFeedback(body).ok,true);
  const record = await store(body);
  assert.deepEqual(record.scan.componentMetadata,entries);
  assert.deepEqual(record.scan.componentMetadataCoverage,coverage);
  assert.equal(JSON.stringify(record).includes('must-not-retain'),false);
  for (const entry of record.scan.componentMetadata.slice(1)) {
    assert.equal(entry.identityEstablished,false); assert.equal(entry.reportedModel,null); assert.equal(entry.model,null);
    assert.equal(entry.firmwareVersion,'v9.0.0.0');
  }
});

test('exact official labels and demonstrated wrapper only; siblings and regional/revision aliases never merge',()=>{
  assert.equal(ddpaiModels.length,133); // identity rows, not a hardware-model count
  assert.equal(recognizedDDPAIModel(fixture.model),'Z100 Master');
  for (const label of ['Z100','Z100 Pro','Z100 Master']) assert.equal(recognizedDDPAIModel('DDPAI '+label),label);
  for (const label of ['Z100 Master Dual','Z100 Master Pro','DZ9999_GLOBAL_Z100 Master','Z100 Master suffix','MINI3X','N5Pro']) {
    assert.equal(recognizedDDPAIModel('DDPAI '+label),null,label);
  }
  assert.equal(recognizedDDPAIModel('DDPAI MINI3X (V3)'),'MINI3X (V3)');
});

test('structured metadata validation rejects unsafe paths, versions, bounds, ambiguous aliases and fabricated identity',()=>{
  const cases = [
    ['sourceFile','/DCIM/207log/ui/ui_20300101120000_000.log'],['sourceFile','DCIM/207log/ui/../ui_20300101120000_000.log'],
    ['sourceFile',sourceFile+'\n'],['sourceFile',sourceFile+'\u0000'],['sourceFile',sourceFile.replaceAll('/','\\')],
    ['sourceLine',0],['sourceLine',1.5],['sourceLine',Number.MAX_SAFE_INTEGER+1],['component','telephoto'],
    ['reportedModel','X'.repeat(81)],['reportedModel','Z100\u202eMaster'],['reportedModel','A/B'],
    ['firmwareVersion','8.0.0.16\n'],['firmwareVersion','wifi password'],['firmwareVersion','A'.repeat(65)],
    ['model','Z100 Pro'],['identityEstablished',false],['sourceKind','kernel_log'],['manufacturer','OTHER']
  ];
  for (const [key,value] of cases) {
    const body=payload(); body.scan.componentMetadata[0][key]=value;
    assert.equal(validateFeedback(body).error,'invalid_component_metadata',`${key}: ${JSON.stringify(value)}`);
  }
  for (const change of [scan=>scan.componentMetadata.push(...Array(30).fill(entries[0])),
    scan=>scan.componentMetadataCoverage.retainedEntries=4,scan=>scan.componentMetadataCoverage.inspectedFiles=0,
    scan=>scan.componentMetadataCoverage.omittedEntries=1,scan=>delete scan.componentMetadataCoverage,
    scan=>scan.componentMetadataCoverage.limited='false']) {
    const body=payload();change(body.scan);assert.equal(validateFeedback(body).error,'invalid_component_metadata');
  }
  const ambiguous=payload();Object.assign(ambiguous.scan.componentMetadata[0],{reportedModel:'DDPAI MINI3X',model:'MINI3X (V3)'});
  assert.equal(validateFeedback(ambiguous).error,'invalid_component_metadata');
  assert.equal(validateFeedback({kind:'bug',message:'Legacy',scan:{}}).ok,true);
});

test('bounded partial and mixed evidence are retained as observations, not rewritten to current owner firmware',async()=>{
  const body=payload();
  body.scan.componentMetadata.push({...entries[0],reportedModel:'DDPAI Z100 Pro',model:'Z100 Pro',sourceLine:30});
  body.scan.componentMetadataCoverage={inspectedFiles:1,retainedEntries:4,omittedEntries:17,limited:true};
  body.training={manufacturer:'DDPAI',model:'Manual label',channelSetup:'4CH',notes:'Owner current firmware is separate'};
  const record=await store(body);
  assert.deepEqual(record.scan.componentMetadata,body.scan.componentMetadata);
  assert.deepEqual(record.scan.componentMetadataCoverage,body.scan.componentMetadataCoverage);
  assert.deepEqual(record.training,body.training);
});

test('synthetic ANSI-framed 3CH observations retain reported protocol roles without hardware inference', async()=>{
  const framing = JSON.parse(readFileSync(new URL('./ddpai-ansi-framing.fixture.json', import.meta.url), 'utf8'));
  assert.equal(framing.lines.length,2);
  const observations = framing.lines.flatMap((line,index)=>{
    assert.equal((line.match(/\x1b\[[0-9;]*m/g) || []).length,2);
    const object=JSON.parse(line.slice(line.indexOf('{"')));
    return ['logging_device','rear','inside'].map(component=>({
      manufacturer:'DDPAI',component,reportedModel:component==='logging_device'?object.model:object[`${component}_model`],
      model:component==='logging_device'?'Z100 Master':null,
      firmwareVersion:component==='logging_device'?object.soft_version:object[`${component}_version`],
      sourceKind:'ddpai_ui_device_info',sourceFile:framing.sourceFile,sourceLine:index+1,
      identityEstablished:component==='logging_device'
    }));
  });
  const body=payload();
  body.scan.componentMetadata=observations;
  body.scan.componentMetadataCoverage.retainedEntries=6;
  const record=await store(body);
  assert.deepEqual(record.scan.componentMetadata,observations);
  assert.equal(JSON.stringify(record).includes('canary'),false);
  for(const entry of record.scan.componentMetadata.filter(e=>e.component!=='logging_device')) {
    assert.equal(entry.reportedModel,'DDPAI DR4004');
    assert.equal(entry.model,null); assert.equal(entry.identityEstablished,false);
    assert.equal(entry.firmwareVersion,'v9.0.0.17');
  }
});

const nativeRoot=process.env.DASHCAM_DDPAI_METADATA_OUTPUT;
test('actual native scan -> frozen private snapshot -> receiver -> exact stored readback; anonymous strips metadata', {skip:!nativeRoot}, async()=>{
  const body=JSON.parse(readFileSync(`${nativeRoot}/ddpai-private.json`,'utf8'));
  assert.equal(validateFeedback(body).ok,true);
  const record=await store(body);
  assert.deepEqual(record.scan.componentMetadata,body.scan.componentMetadata);
  assert.deepEqual(record.scan.componentMetadataCoverage,body.scan.componentMetadataCoverage);
  assert.equal(record.scan.componentMetadata[0].reportedModel,fixture.model);
  assert.equal(record.scan.componentMetadata[0].firmwareVersion,fixture.soft_version);
  assert.equal(record.scan.componentMetadata[0].sourceLine,1);
  assert.equal(record.scan.selectedProfileID,'ddpai-z100-master-main');
  writeFileSync(`${nativeRoot}/ddpai-stored.json`,JSON.stringify(record),{flag:'wx'});
  const anonymous=JSON.parse(readFileSync(`${nativeRoot}/ddpai-public.json`,'utf8'));
  assert.equal(anonymous.componentMetadata,undefined);
  assert.equal(anonymous.componentMetadataCoverage,undefined);
  assert.equal(JSON.stringify(anonymous).includes('ui_20300101120000_000.log'),false);
});

test('all official reference labels and aliases match native Swift exactly without merging ambiguity', {skip:!nativeRoot}, ()=>{
 const results=JSON.parse(readFileSync(`${nativeRoot}/ddpai-model-matches.json`,'utf8'));
 assert.ok(results.length>=ddpaiModels.length);
 for(const row of results)assert.equal(recognizedDDPAIModel(row.input),row.model,row.input);
});
