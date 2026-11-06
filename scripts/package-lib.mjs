const REQUIRED_ENTRIES = [
  "LICENSE",
  "README.md",
  "action.yml",
  "analyzer.mbt",
  "baseline.mbt",
  "cmd/main/init.mbt",
  "cmd/main/main.mbt",
  "cmd/main/moon.pkg",
  "docs/BASELINE.md",
  "examples/safe-baseline.json",
  "moon.mod",
  "moon.pkg",
  "pkg.generated.mbti",
  "report.mbt",
  "suppressions.mbt",
  "types.mbt",
];

const FORBIDDEN_SEGMENTS = new Set([
  ".aws",
  ".codex",
  ".env",
  ".git",
  ".mooncakes",
  "_build",
  "credentials.json",
  "dist",
  "node_modules",
  "work",
]);

export function parseModuleManifest(text) {
  const name = /^name\s*=\s*"([^"]+)"/m.exec(text)?.[1];
  const version = /^version\s*=\s*"([^"]+)"/m.exec(text)?.[1];
  if (!name || !version) {
    throw new Error("moon.mod must contain string name and version fields");
  }
  return { name, version };
}

export function packageArchiveName(moduleName, version) {
  return `${moduleName.replaceAll("/", "-")}-${version}.zip`;
}

export function normalizePackageEntry(entry) {
  return entry.trim().replaceAll("\\", "/").replace(/^\.\//, "");
}

export function listZipEntries(buffer) {
  const view = new DataView(
    buffer.buffer,
    buffer.byteOffset,
    buffer.byteLength,
  );
  const minOffset = Math.max(0, buffer.length - 65_557);
  let endOffset = -1;
  for (let offset = buffer.length - 22; offset >= minOffset; offset -= 1) {
    if (view.getUint32(offset, true) === 0x06054b50) {
      endOffset = offset;
      break;
    }
  }
  if (endOffset < 0) {
    throw new Error("ZIP end-of-central-directory record not found");
  }

  const count = view.getUint16(endOffset + 10, true);
  let offset = view.getUint32(endOffset + 16, true);
  const entries = [];
  for (let index = 0; index < count; index += 1) {
    if (
      offset + 46 > buffer.length ||
      view.getUint32(offset, true) !== 0x02014b50
    ) {
      throw new Error("invalid ZIP central-directory entry");
    }
    const nameLength = view.getUint16(offset + 28, true);
    const extraLength = view.getUint16(offset + 30, true);
    const commentLength = view.getUint16(offset + 32, true);
    const nameStart = offset + 46;
    const nameEnd = nameStart + nameLength;
    if (nameEnd > buffer.length) {
      throw new Error("truncated ZIP central-directory filename");
    }
    entries.push(buffer.subarray(nameStart, nameEnd).toString("utf8"));
    offset = nameEnd + extraLength + commentLength;
  }
  return entries;
}

export function validatePackageEntries(rawEntries) {
  const entries = rawEntries
    .map(normalizePackageEntry)
    .filter((entry) => entry.length > 0);
  const present = new Set(entries);
  const missing = REQUIRED_ENTRIES.filter((entry) => !present.has(entry));
  const unsafe = entries.filter((entry) => {
    return entry.startsWith("/") ||
      /^[A-Za-z]:\//.test(entry) ||
      entry.split("/").includes("..");
  });
  const forbidden = entries.filter((entry) => {
    return entry
      .split("/")
      .some((segment) => FORBIDDEN_SEGMENTS.has(segment));
  });
  return {
    entries,
    missing,
    unsafe,
    forbidden,
    valid: missing.length === 0 &&
      unsafe.length === 0 &&
      forbidden.length === 0,
  };
}
