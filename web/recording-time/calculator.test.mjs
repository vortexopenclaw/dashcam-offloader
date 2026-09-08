import test from 'node:test';
import assert from 'node:assert/strict';
import {calculate, rates} from './calculator.mjs';

const base = {minMbps: 80, maxMbps: 80, allocationPercent: 100, reservePercent: 0};
test('80 Mbps consumes 36 decimal GB per hour, not GiB', () => {
  assert.equal(calculate({...base, cardGB: 360}).minHours, 10);
  assert.equal(calculate({...base, targetHours: 10}).maxGB, 360);
});
test('simultaneous channels add storage rates, never recording durations', () => {
  const combined = rates({channels:[{minMbps:36,maxMbps:36},{minMbps:15.6,maxMbps:15.6},{minMbps:24,maxMbps:24}]});
  assert.equal(combined.maxMbps, 75.6);
  assert.ok(Math.abs(calculate({...base,...combined,cardGB:256,reservePercent:5}).minHours - 7.1487360376) < 0.000001);
});
test('partition and headroom both reduce driving retention', () => {
  assert.equal(calculate({...base,cardGB:360,allocationPercent:50,reservePercent:10}).minHours, 4.5);
});
test('range uses high bitrate for shorter time and larger required card', () => {
  assert.deepEqual(calculate({...base,minMbps:40,cardGB:360}), {minHours:10,maxHours:20});
  assert.deepEqual(calculate({...base,minMbps:40,targetHours:10}), {minGB:180,maxGB:360});
});
test('invalid values never produce plausible outputs', () => {
  for (const patch of [{allocationPercent:NaN},{allocationPercent:0},{allocationPercent:101},{reservePercent:100},{reservePercent:-1},{minMbps:0},{maxMbps:Infinity},{maxMbps:1},{cardGB:-1}]) {
    assert.throws(() => calculate({...base,cardGB:256,...patch}));
  }
});
