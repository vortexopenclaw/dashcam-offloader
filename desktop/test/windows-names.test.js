const test = require("node:test");
const assert = require("node:assert/strict");
const { safeFilename } = require("../src/offload-engine");

test("Windows device names and trailing dots/spaces never reach the destination as-is", () => {
  for (const [input, expected] of [
    ["CON.mp4", "_CON.mp4"], ["con.MP4", "_con.MP4"], ["NUL", "_NUL"], ["com1.mov", "_com1.mov"],
    ["LPT9.tar.mp4", "_LPT9.tar.mp4"], ["aux .mp4", "_aux .mp4"],
    ["clip.mp4.", "clip.mp4"], ["clip.mp4 . ", "clip.mp4"],
    ["CONSOLE.mp4", "CONSOLE.mp4"], ["COM10.mp4", "COM10.mp4"], ["20300101_120000_NF.mp4", "20300101_120000_NF.mp4"],
  ]) assert.equal(safeFilename(`/card/DCIM/${input}`), expected, input);
  for (const bad of ["...", " . "]) assert.throws(() => safeFilename(`/card/${bad}`));
});
