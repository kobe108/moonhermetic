import fs from "node:fs";
import path from "node:path";
import { createMooncakesCredential, moonHome } from "./mooncakes-lib.mjs";
import { parseModuleManifest } from "./package-lib.mjs";

const manifest = parseModuleManifest(fs.readFileSync("moon.mod", "utf8"));
const credential = createMooncakesCredential(
  manifest.name,
  (process.env.MOONCAKES_USERNAME ?? "").trim(),
  process.env.MOONCAKES_TOKEN ?? "",
);
const home = moonHome(
  process.env.HOME || process.env.USERPROFILE,
  process.env.MOON_HOME,
);
fs.mkdirSync(home, { recursive: true });
const credentialPath = path.join(home, "credentials.json");
fs.writeFileSync(credentialPath, JSON.stringify(credential), {
  encoding: "utf8",
  mode: 0o600,
});

console.log(
  `configured isolated Mooncakes credentials for ${credential.username} ` +
  `at ${credentialPath}`,
);
