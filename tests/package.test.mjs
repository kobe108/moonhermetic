import assert from "node:assert/strict";
import test from "node:test";
import {
  listZipEntries,
  packageArchiveName,
  parseModuleManifest,
  validatePackageEntries,
} from "../scripts/package-lib.mjs";
import {
  createMooncakesCredential,
  moonHome,
} from "../scripts/mooncakes-lib.mjs";

const required = [
  "LICENSE",
  "README.md",
  "action.yml",
  "analyzer.mbt",
  "cmd/main/main.mbt",
  "cmd/main/moon.pkg",
  "moon.mod",
  "moon.pkg",
  "pkg.generated.mbti",
  "report.mbt",
  "suppressions.mbt",
  "types.mbt",
];

function zipWithCentralDirectory(entries) {
  const records = entries.map((entry) => {
    const name = Buffer.from(entry, "utf8");
    const record = Buffer.alloc(46 + name.length);
    record.writeUInt32LE(0x02014b50, 0);
    record.writeUInt16LE(name.length, 28);
    name.copy(record, 46);
    return record;
  });
  const centralSize = records.reduce((size, record) => size + record.length, 0);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralSize, 12);
  end.writeUInt32LE(0, 16);
  return Buffer.concat([...records, end]);
}

test("parses module metadata and derives the package filename", () => {
  const manifest = parseModuleManifest(
    'name = "kobe108/moonhermetic"\nversion = "0.10.1"\n',
  );
  assert.deepEqual(manifest, {
    name: "kobe108/moonhermetic",
    version: "0.10.1",
  });
  assert.equal(
    packageArchiveName(manifest.name, manifest.version),
    "kobe108-moonhermetic-0.10.1.zip",
  );
});

test("accepts a complete platform-neutral package", () => {
  const result = validatePackageEntries(
    required.map((entry) => entry.replaceAll("/", "\\")),
  );
  assert.equal(result.valid, true);
  assert.deepEqual(result.missing, []);
  assert.deepEqual(result.unsafe, []);
  assert.deepEqual(result.forbidden, []);
});

test("reads entry names directly from the ZIP central directory", () => {
  assert.deepEqual(
    listZipEntries(zipWithCentralDirectory(["moon.mod", "src\\demo.mbt"])),
    ["moon.mod", "src\\demo.mbt"],
  );
  assert.throws(() => listZipEntries(Buffer.from("not a zip")), /record not found/);
});

test("rejects missing files and release-only directories", () => {
  const result = validatePackageEntries([
    ...required.filter((entry) => entry !== "suppressions.mbt"),
    "_build/native/debug/demo.exe",
    "dist/moonhermetic.zip",
    ".git/config",
  ]);
  assert.equal(result.valid, false);
  assert.deepEqual(result.missing, ["suppressions.mbt"]);
  assert.equal(result.forbidden.length, 3);
});

test("rejects absolute and parent-traversal package paths", () => {
  const result = validatePackageEntries([
    ...required,
    "../credentials.json",
    "/tmp/token",
    "C:\\secret.txt",
  ]);
  assert.equal(result.valid, false);
  assert.equal(result.unsafe.length, 3);
});

test("only creates credentials for the kobe108 Mooncakes identity", () => {
  assert.deepEqual(
    createMooncakesCredential(
      "kobe108/moonhermetic",
      "kobe108",
      "a-secure-mooncakes-token",
    ),
    {
      token: "a-secure-mooncakes-token",
      username: "kobe108",
    },
  );
  assert.throws(
    () => createMooncakesCredential(
      "someone/moonhermetic",
      "kobe108",
      "a-secure-mooncakes-token",
    ),
    /not owned/,
  );
  assert.throws(
    () => createMooncakesCredential(
      "kobe108/moonhermetic",
      "other-user",
      "a-secure-mooncakes-token",
    ),
    /username must be kobe108/,
  );
});

test("uses an explicit or home-based Moon tool directory", () => {
  assert.equal(moonHome("/home/runner", "/tmp/moon"), "/tmp/moon");
  assert.equal(moonHome("C:\\Users\\runner", ""), "C:/Users/runner/.moon");
});
