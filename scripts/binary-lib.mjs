export const ACTION_REPOSITORY = "kobe108/moonhermetic";

export function releasePlatform(platform = process.platform, arch = process.arch) {
  let platformName;
  switch (platform) {
    case "linux":
      platformName = "linux";
      break;
    case "darwin":
      platformName = "macos";
      break;
    case "win32":
      platformName = "windows";
      break;
    default:
      throw new Error(`unsupported release platform '${platform}'`);
  }

  let archName;
  switch (arch) {
    case "x64":
      archName = "x86_64";
      break;
    case "arm64":
      archName = "arm64";
      break;
    default:
      throw new Error(`unsupported release architecture '${arch}'`);
  }

  return {
    platform: platformName,
    arch: archName,
    binaryName: platform === "win32" ? "moonhermetic.exe" : "moonhermetic",
  };
}

export function binaryAssetName(version, platform, arch) {
  const extension = platform === "windows" ? ".exe" : "";
  return `moonhermetic-v${version}-${platform}-${arch}${extension}`;
}

export function releaseDownloadUrl(repository, ref, asset) {
  return `https://github.com/${repository}/releases/download/${ref}/${asset}`;
}

export function parseActionRelease(env) {
  const repository = (env.ACTION_REPOSITORY ?? "").trim();
  const ref = (env.ACTION_REF ?? "").trim();
  if (repository !== ACTION_REPOSITORY) {
    return null;
  }
  const match = /^v(\d+\.\d+\.\d+)$/.exec(ref);
  return match ? { repository, ref, version: match[1] } : null;
}

export function expectedSha256(checksumText, asset) {
  for (const line of checksumText.split(/\r?\n/)) {
    const match = /^([a-fA-F0-9]{64})\s+\*?(.+?)\s*$/.exec(line);
    if (match && match[2] === asset) {
      return match[1].toLowerCase();
    }
  }
  throw new Error(`checksum file does not contain '${asset}'`);
}
