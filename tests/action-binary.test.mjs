import assert from "node:assert/strict";
import test from "node:test";
import {
  binaryAssetName,
  expectedSha256,
  parseActionRelease,
  releaseDownloadUrl,
  releasePlatform,
} from "../scripts/binary-lib.mjs";

test("maps runner platforms and architectures to release assets", () => {
  assert.deepEqual(releasePlatform("linux", "x64"), {
    platform: "linux",
    arch: "x86_64",
    binaryName: "moonhermetic",
  });
  assert.deepEqual(releasePlatform("darwin", "arm64"), {
    platform: "macos",
    arch: "arm64",
    binaryName: "moonhermetic",
  });
  assert.deepEqual(releasePlatform("win32", "x64"), {
    platform: "windows",
    arch: "x86_64",
    binaryName: "moonhermetic.exe",
  });
});

test("builds versioned binary names and release URLs", () => {
  const asset = binaryAssetName("0.14.0", "windows", "x86_64");
  assert.equal(asset, "moonhermetic-v0.14.0-windows-x86_64.exe");
  assert.equal(
    releaseDownloadUrl("kobe108/moonhermetic", "v0.14.0", asset),
    "https://github.com/kobe108/moonhermetic/releases/download/v0.14.0/" +
      "moonhermetic-v0.14.0-windows-x86_64.exe",
  );
});

test("only tagged releases of the canonical repository use binaries", () => {
  assert.deepEqual(
    parseActionRelease({
      ACTION_REPOSITORY: "kobe108/moonhermetic",
      ACTION_REF: "v0.14.0",
    }),
    {
      repository: "kobe108/moonhermetic",
      ref: "v0.14.0",
      version: "0.14.0",
    },
  );
  assert.equal(
    parseActionRelease({
      ACTION_REPOSITORY: "fork/moonhermetic",
      ACTION_REF: "v0.14.0",
    }),
    null,
  );
  assert.equal(
    parseActionRelease({
      ACTION_REPOSITORY: "kobe108/moonhermetic",
      ACTION_REF: "main",
    }),
    null,
  );
});

test("checksum parser requires an exact asset match", () => {
  const hash = "a".repeat(64);
  const asset = "moonhermetic-v0.14.0-linux-x86_64";
  assert.equal(expectedSha256(`${hash}  ${asset}\n`, asset), hash);
  assert.equal(expectedSha256(`${hash.toUpperCase()} *${asset}\r\n`, asset), hash);
  assert.throws(
    () => expectedSha256(`${hash}  another-binary\n`, asset),
    /does not contain/,
  );
});
