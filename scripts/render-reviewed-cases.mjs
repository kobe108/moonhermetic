import fs from "node:fs";
import path from "node:path";

const sourcePath = path.resolve("benchmarks/reviewed-cases.json");
const outputPath = path.resolve("docs/REVIEWED_CASES.md");
const data = JSON.parse(fs.readFileSync(sourcePath, "utf8"));
const cases = data.cases ?? [];

if (data.schema !== "moonhermetic/reviewed-cases-v1") {
  throw new Error(`unexpected reviewed-cases schema: ${data.schema}`);
}
if (cases.length === 0) {
  throw new Error("reviewed-cases.json must not be empty");
}

const ids = new Set();
for (const item of cases) {
  if (
    !item.id ||
    ids.has(item.id) ||
    !item.repository ||
    !item.path ||
    !Number.isInteger(item.line) ||
    !item.ruleId ||
    !["finding", "no-finding"].includes(item.expected) ||
    !item.reason
  ) {
    throw new Error(`invalid reviewed case: ${JSON.stringify(item)}`);
  }
  ids.add(item.id);
}

const positives = cases.filter((item) => item.expected === "finding").length;
const negatives = cases.length - positives;
const escapeCell = (value) => String(value).replaceAll("|", "\\|");
const rows = cases.map(
  (item) =>
    `| \`${escapeCell(item.id)}\` | \`${escapeCell(item.repository)}\` ` +
    `| \`${escapeCell(item.path)}:${item.line}\` | \`${item.ruleId}\` ` +
    `| ${item.expected} | ${escapeCell(item.reason)} |`,
);
const markdown = [
  "# Reviewed benchmark cases",
  "",
  "This report is generated from `benchmarks/reviewed-cases.json`. It records",
  "the positive and negative boundary decisions used to review the heuristic",
  "rules; it is not an accuracy percentage for every corpus finding.",
  "",
  `- Reviewed cases: **${cases.length}**`,
  `- Confirmed findings: **${positives}**`,
  `- Reviewed non-findings: **${negatives}**`,
  "",
  "| Case | Repository | Location | Rule | Decision | Reason |",
  "|---|---|---|---|---|---|",
  ...rows,
  "",
  "A `no-finding` case is an intentionally reviewed boundary where a textual",
  "API-like name does not imply an ambient effect. These cases are regression",
  "tests for false-positive control.",
  "",
].join("\n");

if (process.argv.includes("--write")) {
  fs.writeFileSync(outputPath, markdown, "utf8");
  console.log(`wrote ${outputPath} with ${cases.length} reviewed cases`);
  process.exit(0);
}

const current = fs.existsSync(outputPath)
  ? fs.readFileSync(outputPath, "utf8")
  : "";
if (current !== markdown) {
  throw new Error(
    "docs/REVIEWED_CASES.md is stale; run " +
      "`node scripts/render-reviewed-cases.mjs --write`",
  );
}
console.log(`verified ${cases.length} reviewed cases`);
