import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import {
  binaryAssetName,
  expectedSha256,
  parseActionRelease,
  releaseDownloadUrl,
  releasePlatform,
} from "./binary-lib.mjs";

function appendOutput(name, value) {
  const outputFile = process.env.GITHUB_OUTPUT;
  if (outputFile) {
    fs.appendFileSync(outputFile, `${name}=${value}\n`, "utf8");
  }
}

async function download(url) {
  const response = await fetch(url, {
    redirect: "follow",
    headers: { "user-agent": "MoonHermetic-GitHub-Action" },
  });
  if (response.status === 404) {
    return null;
  }
  if (!response.ok) {
    throw new Error(`download failed with HTTP ${response.status}: ${url}`);
  }
  return Buffer.from(await response.arrayBuffer());
}

async function main() {
  appendOutput("available", "false");
  appendOutput("binary-path", "");
  appendOutput("mode", "source");

  const release = parseActionRelease(process.env);
  if (!release) {
    console.log("::notice title=MoonHermetic::Using the MoonBit source fallback.");
    return;
  }

  const target = releasePlatform();
  const asset = binaryAssetName(
    release.version,
    target.platform,
    target.arch,
  );
  const binaryUrl = releaseDownloadUrl(release.repository, release.ref, asset);
  const checksumUrl = `${binaryUrl}.sha256`;

  let binary;
  let checksum;
  try {
    binary = await download(binaryUrl);
    checksum = await download(checksumUrl);
  } catch (error) {
    console.warn(
      `::warning title=MoonHermetic::Prebuilt binary unavailable; using the MoonBit source fallback. ${error instanceof Error ? error.message : String(error)}`,
    );
    return;
  }
  if (!binary || !checksum) {
    console.log(
      "::notice title=MoonHermetic::No prebuilt binary for this runner; using the MoonBit source fallback.",
    );
    return;
  }

  const expected = expectedSha256(checksum.toString("utf8"), asset);
  const actual = createHash("sha256").update(binary).digest("hex");
  if (expected !== actual) {
    throw new Error(`checksum mismatch for ${asset}`);
  }

  const tempRoot = path.resolve(
    process.env.RUNNER_TEMP || path.join(process.cwd(), ".tmp"),
    "moonhermetic",
  );
  fs.mkdirSync(tempRoot, { recursive: true });
  const binaryPath = path.join(tempRoot, target.binaryName);
  fs.writeFileSync(binaryPath, binary);
  if (process.platform !== "win32") {
    fs.chmodSync(binaryPath, 0o755);
  }

  appendOutput("available", "true");
  appendOutput("binary-path", binaryPath);
  appendOutput("mode", "binary");
  console.log(
    `::notice title=MoonHermetic::Using verified prebuilt binary ${release.ref} for ${target.platform}-${target.arch}.`,
  );
}

main().catch((error) => {
  console.error(
    `::error title=MoonHermetic::${error instanceof Error ? error.message : String(error)}`,
  );
  process.exit(2);
});
