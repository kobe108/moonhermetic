import fs from "node:fs";
import path from "node:path";

const frameDir = path.resolve("dist/demo-frames");
const outputPath = path.resolve("dist/moonhermetic-demo.avi");
const framesPerSecond = Number(process.env.DEMO_FPS ?? 2);
const frames = fs
  .readdirSync(frameDir)
  .filter((name) => /^frame-\d+\.jpg$/.test(name))
  .sort()
  .map((name) => fs.readFileSync(path.join(frameDir, name)));

if (frames.length < 10) {
  throw new Error("not enough rendered demo frames");
}

const width = 1280;
const height = 720;
const pad = (size) => size + (size % 2);
const chunk = (id, payload) => {
  const header = Buffer.alloc(8);
  header.write(id, 0, 4, "ascii");
  header.writeUInt32LE(payload.length, 4);
  const padding = payload.length % 2 ? Buffer.alloc(1) : Buffer.alloc(0);
  return Buffer.concat([header, payload, padding]);
};
const list = (kind, payload) => {
  const body = Buffer.concat([Buffer.from(kind, "ascii"), payload]);
  const header = Buffer.alloc(12);
  header.write("LIST", 0, 4, "ascii");
  header.writeUInt32LE(body.length, 4);
  header.write(kind, 8, 4, "ascii");
  return Buffer.concat([header, payload]);
};

const avih = Buffer.alloc(56);
avih.writeUInt32LE(Math.round(1_000_000 / framesPerSecond), 0);
avih.writeUInt32LE(Math.max(...frames.map((frame) => frame.length)) * framesPerSecond, 4);
avih.writeUInt32LE(0, 8);
avih.writeUInt32LE(0x10, 12);
avih.writeUInt32LE(frames.length, 16);
avih.writeUInt32LE(0, 20);
avih.writeUInt32LE(1, 24);
avih.writeUInt32LE(width * height * 3, 28);
avih.writeUInt32LE(width, 32);
avih.writeUInt32LE(height, 36);

const strh = Buffer.alloc(56);
strh.write("vids", 0, 4, "ascii");
strh.write("MJPG", 4, 4, "ascii");
strh.writeUInt32LE(0, 8);
strh.writeUInt16LE(0, 12);
strh.writeUInt16LE(0, 14);
strh.writeUInt32LE(0, 16);
strh.writeUInt32LE(1, 20);
strh.writeUInt32LE(framesPerSecond, 24);
strh.writeUInt32LE(0, 28);
strh.writeUInt32LE(frames.length, 32);
strh.writeUInt32LE(width * height * 3, 36);
strh.writeUInt32LE(0xffffffff, 40);
strh.writeUInt32LE(0, 44);
strh.writeInt16LE(0, 48);
strh.writeInt16LE(0, 50);
strh.writeInt16LE(width, 52);
strh.writeInt16LE(height, 54);

const strf = Buffer.alloc(40);
strf.writeUInt32LE(40, 0);
strf.writeInt32LE(width, 4);
strf.writeInt32LE(height, 8);
strf.writeUInt16LE(1, 12);
strf.writeUInt16LE(24, 14);
strf.write("MJPG", 16, 4, "ascii");
strf.writeUInt32LE(width * height * 3, 20);

const strl = list("strl", Buffer.concat([chunk("strh", strh), chunk("strf", strf)]));
const hdrl = list("hdrl", Buffer.concat([chunk("avih", avih), strl]));
const moviHeader = Buffer.alloc(12);
moviHeader.write("LIST", 0, 4, "ascii");
moviHeader.write("movi", 8, 4, "ascii");

const frameChunks = [];
const indexEntries = [];
let moviOffset = 4;
for (const frame of frames) {
  const payload = frame;
  const frameChunk = chunk("00dc", payload);
  indexEntries.push({ offset: moviOffset, size: payload.length });
  frameChunks.push(frameChunk);
  moviOffset += frameChunk.length;
}

const idx = Buffer.alloc(16 * indexEntries.length);
indexEntries.forEach((entry, index) => {
  const offset = index * 16;
  idx.write("00dc", offset, 4, "ascii");
  idx.writeUInt32LE(0x10, offset + 4);
  idx.writeUInt32LE(entry.offset, offset + 8);
  idx.writeUInt32LE(entry.size, offset + 12);
});

const moviBody = Buffer.concat(frameChunks);
const movi = Buffer.concat([
  moviHeader,
  moviBody,
  moviBody.length % 2 ? Buffer.alloc(1) : Buffer.alloc(0),
]);
movi.writeUInt32LE(movi.length - 8, 4);
const idxChunk = chunk("idx1", idx);
const riffBody = Buffer.concat([
  Buffer.from("AVI ", "ascii"),
  hdrl,
  movi,
  idxChunk,
]);
const riffHeader = Buffer.alloc(8);
riffHeader.write("RIFF", 0, 4, "ascii");
riffHeader.writeUInt32LE(riffBody.length, 4);
fs.writeFileSync(outputPath, Buffer.concat([riffHeader, riffBody]));
console.log(
  `wrote ${outputPath} with ${frames.length} frames ` +
    `(${frames.length / framesPerSecond}s at ${framesPerSecond}fps)`,
);
