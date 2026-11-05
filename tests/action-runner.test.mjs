import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";
import { createActionPlan, parseBoolean } from "../scripts/action-lib.mjs";

const workspace = path.resolve("/workspace/project");
const actionPath = path.resolve("/actions/moonhermetic");

function plan(inputs = {}, fileExists = () => false) {
  return createActionPlan(
    inputs,
    { workspace, actionPath, fileExists },
  );
}

test("scan defaults to SARIF and a workspace-relative report", () => {
  const result = plan();
  assert.equal(result.audit, false);
  assert.equal(result.format, "sarif");
  assert.equal(result.outputPath, path.join(workspace, "moonhermetic.sarif"));
  assert.deepEqual(result.args.slice(0, 6), [
    "run",
    "cmd/main",
    "--",
    workspace,
    "--format",
    "sarif",
  ]);
  assert.ok(result.args.includes("--no-config"));
});

test("audit defaults to JSON and enables the governance report", () => {
  const result = plan({ INPUT_AUDIT_SUPPRESSIONS: "true" });
  assert.equal(result.audit, true);
  assert.equal(result.format, "json");
  assert.equal(
    result.outputPath,
    path.join(workspace, "moonhermetic-suppressions.json"),
  );
  assert.ok(result.args.includes("--audit-suppressions"));
});

test("governance failure input implies an audit and adds the gate", () => {
  const result = plan({ INPUT_FAIL_ON_SUPPRESSION: "yes" });
  assert.equal(result.audit, true);
  assert.ok(result.args.includes("--audit-suppressions"));
  assert.ok(result.args.includes("--fail-on-suppression"));
});

test("caller config is discovered and explicit paths stay in the workspace", () => {
  const discovered = plan({}, (candidate) => {
    return candidate === path.join(workspace, ".moonhermetic.json");
  });
  assert.ok(discovered.args.includes("--config"));
  assert.ok(
    discovered.args.includes(path.join(workspace, ".moonhermetic.json")),
  );

  const explicit = plan({ INPUT_CONFIG: "config/policy.json" });
  assert.ok(
    explicit.args.includes(path.join(workspace, "config", "policy.json")),
  );
});

test("path diff excludes and stdout output are forwarded safely", () => {
  const result = plan({
    INPUT_PATH: "tests",
    INPUT_DIFF: "changes.diff",
    INPUT_EXCLUDE: "vendor\ngenerated",
    INPUT_OUTPUT_FILE: "-",
  });
  assert.ok(result.args.includes(path.join(workspace, "tests")));
  assert.ok(result.args.includes(path.join(workspace, "changes.diff")));
  assert.ok(result.args.includes("vendor"));
  assert.ok(result.args.includes("generated"));
  assert.equal(result.outputPath, null);
});

test("format and boolean inputs reject invalid values", () => {
  assert.throws(() => plan({ INPUT_FORMAT: "html" }), /format must be/);
  assert.throws(
    () => plan({ INPUT_AUDIT_SUPPRESSIONS: "true", INPUT_FORMAT: "sarif" }),
    /supports only text or json/,
  );
  assert.throws(
    () => plan({ INPUT_AUDIT_SUPPRESSIONS: "maybe" }),
    /must be true or false/,
  );
});

test("boolean parser accepts common action input spellings", () => {
  for (const value of ["", "false", "0", "no", "FALSE"]) {
    assert.equal(parseBoolean(value, "flag"), false);
  }
  for (const value of ["true", "1", "yes", "TRUE"]) {
    assert.equal(parseBoolean(value, "flag"), true);
  }
});
