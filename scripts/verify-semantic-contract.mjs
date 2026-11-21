const mode = process.argv[2];
const envName = mode === "legacy"
  ? "MOONHERMETIC_ACCEPTANCE_LEGACY"
  : "MOONHERMETIC_ACCEPTANCE_JSON";
const text = process.env[envName] ?? "";
const start = text.indexOf("{");
if (start < 0) {
  throw new Error(`${mode} report does not contain a JSON object`);
}

const report = JSON.parse(text.slice(start));
if (mode === "legacy") {
  if (report.summary?.findings !== 2) {
    throw new Error(
      `legacy report expected 2 findings, got ${report.summary?.findings}`,
    );
  }
  process.exit(0);
}

const finding = report.findings?.[0];
const expected = [
  "cross-file request reads an ambient token",
  "prepare_request",
  "read_ambient_token",
].join(" -> ");
if (
  report.summary?.findings !== 1 ||
  !finding?.path.endsWith("request.mbt") ||
  finding.callPath?.join(" -> ") !== expected
) {
  throw new Error("semantic report does not match the cross-file contract");
}
