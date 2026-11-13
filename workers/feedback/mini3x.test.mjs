import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import worker, {validateFeedback} from './worker.js';
import {recognizedDDPAIModel} from './ddpai-models.js';

async function roundtrip(scan) {
  const body = {kind:'bug', message:'Local MINI3X evidence verification', scan};
  assert.equal(validateFeedback(body).ok, true);
  const records = new Map();
  const env = {RATE_LIMIT_SALT:'synthetic-fixture-only-not-a-secret'.repeat(2),
    FEEDBACK_RATE_LIMITER:{idFromName:n=>n,get:()=>({fetch:async()=>Response.json({ok:true})})},
    FEEDBACK_KV:{put:async(k,v)=>records.set(k,v),get:async k=>records.get(k)}};
  const response = await worker.fetch(new Request('https://example.test/feedback', {
    method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)}), env);
  assert.equal(response.status,202);
  const receipt = await response.json();
  assert.equal(records.size,1);
  const [key] = records.keys();
  assert.ok(key.includes(receipt.id));
  const stored = JSON.parse(await env.FEEDBACK_KV.get(key));
  assert.equal(stored.id,receipt.id);
  assert.deepEqual(stored.scan.componentMetadata,scan.componentMetadata);
  const pairs = s => (s.videoSpecSummaries || []).flatMap(g=>g.storageRateSamples || []);
  assert.deepEqual(pairs(stored.scan),pairs(scan));
  return stored;
}

test('MINI3X exact SKU retains generic model and logging firmware through production receiver', async()=>{
  for (const sku of ['dm003_overseas_v2', 'ddpai dm003_overseas_v2', 'DDPAI DM003_Overseas_V2']) assert.equal(recognizedDDPAIModel(sku),'MINI3X');
  for (const sku of ['DDPAI DM003_Overseas_V3','DDPAI MINI3X','DDPAI DM003_Overseas_V2 suffix']) {
    assert.equal(recognizedDDPAIModel(sku),null);
  }
  const entry = {manufacturer:'DDPAI',component:'logging_device',reportedModel:'DDPAI DM003_Overseas_V2',
    model:'MINI3X',firmwareVersion:'v9.0.1.10',sourceKind:'ddpai_product_info',
    sourceFile:'DCIM/207log/20300101120000_000.log',sourceLine:1,identityEstablished:true};
  await roundtrip({componentMetadata:[entry],componentMetadataCoverage:{inspectedFiles:1,retainedEntries:1,omittedEntries:0,limited:false}});
  for (const model of ['MINI3X (V3)','Z100 Master']) {
    assert.equal(validateFeedback({kind:'bug',message:'Synthetic',scan:{componentMetadata:[{...entry,model}],componentMetadataCoverage:{inspectedFiles:1,retainedEntries:1,omittedEntries:0,limited:false}}}).ok,false);
  }
});

test('optional authorized native card snapshot preserves every paired occurrence and component observation', {
  skip:!process.env.DASHCAM_MINI3X_NATIVE_SNAPSHOT
}, async()=>{
  const scan = JSON.parse(readFileSync(process.env.DASHCAM_MINI3X_NATIVE_SNAPSHOT,'utf8'));
  assert.equal(scan.selectedProfileID,'ddpai-mini3x');
  assert.ok(scan.componentMetadata.every(e=>e.model==='MINI3X' && e.firmwareVersion==='v9.0.1.10'));
  const pairs=scan.videoSpecSummaries.flatMap(g=>g.storageRateSamples || []);
  assert.equal(pairs.length,23);
  assert.ok(pairs.every(p=>p.codec==='H.265 / HEVC'));
  const stored=await roundtrip(scan);
  assert.equal(stored.scan.selectedProfileID,'ddpai-mini3x');
});
