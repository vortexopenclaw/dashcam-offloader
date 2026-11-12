import {test} from "node:test";
import assert from "node:assert/strict";
import {readFileSync, writeFileSync} from "node:fs";
import worker, {sanitizeScan, validateFeedback} from "./worker.js";

const pairs = scan => scan.videoSpecSummaries.flatMap(summary => summary.storageRateSamples.map(pair => ({
  ...pair, channel: summary.channel, mode: summary.mode
})));
const numeric = pair => Object.fromEntries(["fileSizeBytes", "durationSeconds", "width", "height", "nominalFrameRate", "videoBitrate"].map(key => [key, pair[key] ?? null]));

test("unfamiliar private identities survive together; unsafe identities never destroy legacy pairs", () => {
  const measurement = {fileSizeBytes:12345,durationSeconds:1.5,videoBitrate:60000};
  const valid = {sourceIdentifier:"source-1",filename:"N_20300102123456_0001.MP4",folder:"DCIM/inside/200video"};
  const unsafe = ["../a.mp4", "/a.mp4", "a\\b.mp4", "a\n.mp4", "._a.mp4", "a..mp4", "a.ini", "a".repeat(181)+".mp4"];
  for (const filename of unsafe) {
    const scan = sanitizeScan({filenameSamples:[filename], mediaFileSamples:[{...valid,filename}],
      videoSpecSummaries:[{storageRateSamples:[{...measurement,...valid,filename}]}]});
    assert.deepEqual(scan.filenameSamples,[]);
    assert.deepEqual(scan.mediaFileSamples,[]);
    assert.equal(scan.videoSpecSummaries[0].storageRateSamples.length,1);
    assert.equal(scan.videoSpecSummaries[0].storageRateSamples[0].filename,undefined);
    assert.equal(scan.videoSpecSummaries[0].storageRateSamples[0].fileSizeBytes,12345);
  }
  for (const folder of ["/DCIM", "DCIM/../video", "DCIM//video", "DCIM/Family Trip", "DCIM/inside\n", "DCIM/200video\n", "folder-1\n"]) {
    assert.equal(sanitizeScan({videoSpecSummaries:[{storageRateSamples:[{...measurement,...valid,folder}]}]})
      .videoSpecSummaries[0].storageRateSamples[0].filename, undefined);
  }
  assert.equal(sanitizeScan({videoSpecSummaries:[{storageRateSamples:[{...measurement,...valid,sourceIdentifier:"source-1\n"}]}]})
    .videoSpecSummaries[0].storageRateSamples[0].sourceIdentifier, undefined);
  const sample = sanitizeScan({videoSpecSummaries:[{storageRateSamples:[{...measurement,...valid}]}]})
    .videoSpecSummaries[0].storageRateSamples[0];
  for (const key of Object.keys(valid)) assert.equal(sample[key],valid[key]);
});

test("receiving caps recompute retention counts rather than silently claiming completeness", () => {
  const samples = Array.from({length:200}, (_,n) => ({sourceIdentifier:`source-${n+1}`,
    filename:`new-camera-${n}.M4V`,folder:"DCIM/inside/200video",fileSizeBytes:100,durationSeconds:1}));
  const scan = sanitizeScan({mediaFileSamples:samples, videoSpecSummaries:[{storageRateSamples:samples}],
    evidenceCounts:{inventoriedMedia:200,inventoriedVideos:200,measuredVideos:200}});
  assert.equal(scan.mediaFileSamples.length,120);
  assert.equal(scan.videoSpecSummaries[0].storageRateSamples.length,64);
  assert.deepEqual(scan.evidenceCounts,{inventoriedMedia:200,inventoriedVideos:200,measuredVideos:200,
    retainedIdentities:120,omittedIdentities:80,retainedMeasurements:64,omittedMeasurements:136});
});

test("HTTP validation rejects conflicting source links, while legacy pairs remain valid", () => {
  const pair = {fileSizeBytes:100,durationSeconds:1,sourceIdentifier:"source-1",filename:"N_new.MP4",folder:"DCIM/200video"};
  const payload = second => ({kind:"bug",message:"Synthetic",scan:{videoSpecSummaries:[{storageRateSamples:[pair,second]}]}});
  assert.equal(validateFeedback(payload({...pair,folder:"DCIM/inside/200video"})).error,"conflicting_media_identity");
  assert.equal(validateFeedback(payload({...pair,sourceIdentifier:"source-2"})).error,"conflicting_media_identity");
  assert.equal(validateFeedback(payload({fileSizeBytes:100,durationSeconds:1})).ok,true);
});

test("receiver retains its 1 MiB declared and streamed request caps", async () => {
  const env = {RATE_LIMIT_SALT:"synthetic-test-only".repeat(3),
    FEEDBACK_RATE_LIMITER:{idFromName:name => name,get:() => ({fetch:async () => Response.json({ok:true})})},
    FEEDBACK_KV:{put:async () => assert.fail("oversized request must not be stored")}};
  const body = JSON.stringify({kind:"bug",message:"x".repeat(1024*1024)});
  for (const headers of [{"Content-Type":"application/json"}, {"Content-Length":String(1024*1024+1)}]) {
    assert.equal((await worker.fetch(new Request("https://example.test/feedback",{method:"POST",headers,body}),env)).status,413);
  }
});

const nativeRoot = process.env.DASHCAM_NATIVE_EVIDENCE_OUTPUT;
test("actual native snapshot -> HTTP validator/sanitizer -> exact mock KV readback", {skip:!nativeRoot}, async () => {
  for (const label of ["small","large","structural"]) {
    const originalBytes = readFileSync(`${nativeRoot}/${label}.json`,"utf8");
    const submitted = JSON.parse(originalBytes);
    assert.equal(validateFeedback(submitted).ok,true);
    const stored = new Map();
    const env = {RATE_LIMIT_SALT:"synthetic-fixture-only-not-a-secret".repeat(2),
      FEEDBACK_RATE_LIMITER:{idFromName:name => name, get:() => ({fetch:async () => Response.json({ok:true})})},
      FEEDBACK_KV:{put:async (key, value) => {assert.equal(stored.has(key),false);stored.set(key,value);},
        get:async key => stored.get(key)}};
    const response = await worker.fetch(new Request("https://example.test/feedback",{method:"POST",
      headers:{"Content-Type":"application/json"},body:originalBytes}),env);
    assert.equal(response.status,202);
    const receipt = await response.json();
    const [key] = [...stored.keys()];
    assert.ok(key.includes(receipt.id));
    const record = JSON.parse(await env.FEEDBACK_KV.get(key));
    assert.equal(record.id,receipt.id);
    writeFileSync(`${nativeRoot}/${label}-stored.json`,JSON.stringify(record),{flag:"wx"});
    const before = pairs(submitted.scan), after = pairs(record.scan);
    assert.equal(after.length,label === "small" ? 4 : label === "large" ? 64 : 0);
    assert.deepEqual(after,before);
    assert.deepEqual(record.scan.evidenceCounts, submitted.scan.evidenceCounts);
    for (const pair of after) {
      const file = record.scan.mediaFileSamples.find(file => file.sourceIdentifier === pair.sourceIdentifier);
      if (file) for (const field of ["filename","folder","channel","mode"]) assert.equal(file[field],pair[field]);
    }
    assert.equal(new Set(after.map(pair => pair.sourceIdentifier)).size,after.length);
    if (label === "small") {
      const photo = record.scan.mediaFileSamples.find(sample => sample.filename === "IMG_20300102_new.JPG");
      assert.ok(photo?.sourceIdentifier);
      assert.equal(photo.folder,"DCIM/201photo");
      assert.equal(record.scan.evidenceCounts.inventoriedMedia,5);
      const duplicates = after.filter(pair => pair.filename === "N_20300102123456_0001.MP4");
      assert.equal(duplicates.length,2);
      assert.notEqual(duplicates[0].sourceIdentifier,duplicates[1].sourceIdentifier);
      assert.deepEqual(new Set(duplicates.map(pair => pair.folder)),new Set(["DCIM/200video","DCIM/inside/200video"]));
    }
    const anonymous = JSON.parse(readFileSync(`${nativeRoot}/${label}-public.json`,"utf8"));
    assert.deepEqual(pairs(anonymous).map(numeric),before.map(numeric));
    for (const pair of pairs(anonymous)) for (const field of ["filename","folder","sourceIdentifier"]) assert.equal(pair[field],undefined);
    assert.equal(JSON.stringify(anonymous).includes("20300102"),false);
    assert.equal(JSON.stringify(anonymous).includes("inside"),false);
    console.log(`NATIVE STORED ROUNDTRIP PASS ${label}: ${after.length} linked pairs, exact KV key readback, public stripping`);
  }
});
