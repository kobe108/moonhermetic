import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import {
  listZipEntries,
  packageArchiveName,
  parseModuleManifest,
  validatePackageEntries,
} from "./package-lib.mjs";

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

const manifest = parseModuleManifest(fs.readFileSync("moon.mod", "utf8"));
const expectedArchive = path.join(
  "_build",
  "publish",
  packageArchiveName(manifest.name, manifest.version),
);
const archivePath = path.resolve(argument("--archive") || expectedArchive);
if (!fs.existsSync(archivePath)) {
  throw new Error(`package archive not found: ${archivePath}`);
}

const entries = listZipEntries(fs.readFileSync(archivePath));
const validation = validatePackageEntries(entries);
if (!validation.valid) {
  const details = [];
  if (validation.missing.length) {
    details.push(`missing: ${validation.missing.join(", ")}`);
  }
  if (validation.unsafe.length) {
    details.push(`unsafe: ${validation.unsafe.join(", ")}`);
  }
  if (validation.forbidden.length) {
    details.push(`forbidden: ${validation.forbidden.join(", ")}`);
  }
  throw new Error(`invalid package contents (${details.join("; ")})`);
}

const sha256 = createHash("sha256")
  .update(fs.readFileSync(archivePath))
  .digest("hex");
const outputDirectory = argument("--output");
let releaseAsset = "";
if (outputDirectory) {
  const output = path.resolve(outputDirectory);
  fs.mkdirSync(output, { recursive: true });
  const assetName = `moonhermetic-v${manifest.version}-mooncakes.zip`;
  const destination = path.join(output, assetName);
  fs.copyFileSync(archivePath, destination);
  fs.writeFileSync(
    `${destination}.sha256`,
    `${sha256}  ${assetName}\n`,
    "utf8",
  );
  releaseAsset = destination;
}

console.log(
  `validated ${validation.entries.length} package entries for ` +
  `${manifest.name}@${manifest.version}`,
);
console.log(`SHA256 ${sha256}`);
if (releaseAsset) {
  console.log(`release asset ${releaseAsset}`);
}
