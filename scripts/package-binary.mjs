import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { binaryAssetName, releasePlatform } from "./binary-lib.mjs";

const versionMatch = /^version\s*=\s*"([^"]+)"/m.exec(
  fs.readFileSync("moon.mod", "utf8"),
);
if (!versionMatch) {
  throw new Error("could not read version from moon.mod");
}
const version = versionMatch[1];
const ref = (process.env.GITHUB_REF_NAME ?? "").trim();
if (ref.startsWith("v") && ref !== `v${version}`) {
  throw new Error(`release tag ${ref} does not match moon.mod version ${version}`);
}

const target = releasePlatform();
const binaryName = binaryAssetName(
  version,
  target.platform,
  target.arch,
);
const candidates = [
  path.join("_build", "native", "release", "build", "cmd", "main", target.binaryName),
  path.join("_build", "native", "release", "build", "cmd", "main", "main.exe"),
  path.join("_build", "native", "release", "build", "cmd", "main", "main"),
];
const source = candidates.find((candidate) => fs.existsSync(candidate));
if (!source) {
  throw new Error(`release binary not found in ${candidates.join(", ")}`);
}

const dist = path.resolve("dist");
fs.mkdirSync(dist, { recursive: true });
const destination = path.join(dist, binaryName);
fs.copyFileSync(source, destination);
if (process.platform !== "win32") {
  fs.chmodSync(destination, 0o755);
}

const sha256 = createHash("sha256")
  .update(fs.readFileSync(destination))
  .digest("hex");
fs.writeFileSync(
  `${destination}.sha256`,
  `${sha256}  ${binaryName}\n`,
  "utf8",
);

console.log(`${binaryName} ${sha256}`);
