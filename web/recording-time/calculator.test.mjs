import test from 'node:test';
import assert from 'node:assert/strict';
import {recordingRows, rowLabel, timeLabel} from './calculator.mjs';
test('all card sizes appear, use decimal units and no hidden headroom',()=>{
  const rows=recordingRows({minMbps:80,maxMbps:80});
  assert.deepEqual(rows.map(r=>r.gb),[32,64,128,256,512]);
  assert.equal(rows[3].hours,256/36);
});
test('manufacturer times preserve individual rounded cells without scaling',()=>{
  const rows=recordingRows({hours:[1,2,4,8.5,17]});
  assert.equal(rowLabel(rows[3]),'8 hr 30 min');
  assert.equal(rows[0].hours,1);
});
test('one estimate uses the midpoint rate, not the midpoint of recording times',()=>{
  const rows=recordingRows({minMbps:40,maxMbps:80});
  assert.equal(rows[1].hours,64/(60*0.45));
  assert.equal(rowLabel(rows[1]),'2 hr 20 min');
  assert.ok(!rowLabel(rows[1]).includes('–'));
});
test('measured storage mean takes precedence over range midpoint',()=>{
  assert.equal(recordingRows({minMbps:40,maxMbps:80,estimatedMbps:50})[1].hours,64/(50*0.45));
  for (const rate of [0,90,NaN]) assert.throws(()=>recordingRows({minMbps:40,maxMbps:80,estimatedMbps:rate}));
});
test('times round to readable five-minute increments',()=>{
  assert.equal(timeLabel(0.93),'55 min');
  assert.equal(timeLabel(8.5),'8 hr 30 min');
  assert.equal(timeLabel(1),'1 hr');
});
test('invalid source data does not produce a plausible chart',()=>{
  for(const setup of [{hours:[1]},{hours:[1,2,NaN,4,5]},{minMbps:0,maxMbps:2},{minMbps:20,maxMbps:10},{minMbps:2,maxMbps:Infinity}])assert.throws(()=>recordingRows(setup));
});
