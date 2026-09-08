import test from 'node:test';
import assert from 'node:assert/strict';
import {recordingRows, rowLabel, timeLabel} from './calculator.mjs';
test('all card sizes appear, use decimal units and no hidden headroom',()=>{
  const rows=recordingRows({minMbps:80,maxMbps:80});
  assert.deepEqual(rows.map(r=>r.gb),[32,64,128,256,512]);
  assert.equal(rows[3].minHours,256/36);
});
test('manufacturer times preserve individual rounded cells without scaling',()=>{
  const rows=recordingRows({hours:[1,2,4,8.5,17]});
  assert.equal(rowLabel(rows[3]),'8 hr 30 min');
  assert.equal(rows[0].minHours,1);
});
test('higher bitrate means shorter duration; ranges stay ranges',()=>{
  const rows=recordingRows({minMbps:40,maxMbps:80});
  assert.equal(rows[1].maxHours,2*rows[1].minHours);
  assert.match(rowLabel(rows[1]),/ – /);
});
test('times round to readable five-minute increments',()=>{
  assert.equal(timeLabel(0.93),'55 min');
  assert.equal(timeLabel(8.5),'8 hr 30 min');
  assert.equal(timeLabel(1),'1 hr');
});
test('invalid source data does not produce a plausible chart',()=>{
  for(const setup of [{hours:[1]},{hours:[1,2,NaN,4,5]},{minMbps:0,maxMbps:2},{minMbps:20,maxMbps:10},{minMbps:2,maxMbps:Infinity}])assert.throws(()=>recordingRows(setup));
});
