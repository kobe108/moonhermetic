import path from "node:path";
import fs from "node:fs";

const FORMATS = new Set(["text", "json", "markdown", "md", "sarif"]);
const FAIL_THRESHOLDS = new Set(["never", "warning", "error"]);

function input(env, name) {
  return (env[name] ?? "").trim();
}

export function parseBoolean(raw, name) {
  switch ((raw ?? "").trim().toLowerCase()) {
    case "":
    case "false":
    case "0":
    case "no":
      return false;
    case "true":
    case "1":
    case "yes":
      return true;
    default:
      throw new Error(`${name} must be true or false`);
  }
}

function resolveFromWorkspace(workspace, value) {
  return path.isAbsolute(value) ? path.normalize(value) : path.resolve(workspace, value);
}

function defaultOutputName(audit, format) {
  const stem = audit ? "moonhermetic-suppressions" : "moonhermetic";
  switch (format) {
    case "json":
      return `${stem}.json`;
    case "markdown":
    case "md":
      return `${stem}.md`;
    case "sarif":
      return `${stem}.sarif`;
    default:
      return `${stem}.txt`;
  }
}

export function createActionPlan(
  env,
  {
    workspace,
    actionPath,
    fileExists = fs.existsSync,
  },
) {
  if (!workspace) {
    throw new Error("GITHUB_WORKSPACE is required");
  }
  if (!actionPath) {
    throw new Error("ACTION_PATH is required");
  }

  const resolvedWorkspace = path.resolve(workspace);
  const resolvedActionPath = path.resolve(actionPath);
  const audit = parseBoolean(
    input(env, "INPUT_AUDIT_SUPPRESSIONS"),
    "audit-suppressions",
  ) || parseBoolean(
    input(env, "INPUT_FAIL_ON_SUPPRESSION"),
    "fail-on-suppression",
  );
  const failOnSuppression = parseBoolean(
    input(env, "INPUT_FAIL_ON_SUPPRESSION"),
    "fail-on-suppression",
  );
  const format = (input(env, "INPUT_FORMAT") || (audit ? "json" : "sarif")).toLowerCase();
  if (!FORMATS.has(format)) {
    throw new Error(
      `format must be text, json, markdown, or sarif; received '${format}'`,
    );
  }
  if (
    audit &&
    !["text", "json"].includes(format)
  ) {
    throw new Error("a suppression audit supports only text or json output");
  }

  const failOn = (input(env, "INPUT_FAIL_ON") || "error").toLowerCase();
  if (!FAIL_THRESHOLDS.has(failOn)) {
    throw new Error(
      `fail-on must be never, warning, or error; received '${failOn}'`,
    );
  }

  const target = resolveFromWorkspace(
    resolvedWorkspace,
    input(env, "INPUT_PATH") || ".",
  );
  const args = [
    "run",
    "cmd/main",
    "--",
    target,
    "--format",
    format,
    "--fail-on",
    failOn,
  ];

  const explicitConfig = input(env, "INPUT_CONFIG");
  const discoveredConfig = path.join(resolvedWorkspace, ".moonhermetic.json");
  if (explicitConfig) {
    args.push(
      "--config",
      resolveFromWorkspace(resolvedWorkspace, explicitConfig),
    );
  } else if (fileExists(discoveredConfig)) {
    args.push("--config", discoveredConfig);
  } else {
    args.push("--no-config");
  }

  const diff = input(env, "INPUT_DIFF");
  if (diff) {
    args.push(
      "--diff",
      resolveFromWorkspace(resolvedWorkspace, diff),
    );
  }

  const baseline = input(env, "INPUT_BASELINE");
  if (baseline) {
    args.push(
      "--baseline",
      resolveFromWorkspace(resolvedWorkspace, baseline),
    );
  }

  for (const excluded of input(env, "INPUT_EXCLUDE").split(/\r?\n/)) {
    if (excluded.trim()) {
      args.push("--exclude", excluded.trim());
    }
  }

  if (audit) {
    args.push("--audit-suppressions");
  }
  if (failOnSuppression) {
    args.push("--fail-on-suppression");
  }

  const summaryInput = input(env, "INPUT_SUMMARY");
  const summary = summaryInput === "" ? true : parseBoolean(summaryInput, "summary");
  const prComment = parseBoolean(input(env, "INPUT_PR_COMMENT"), "pr-comment");
  const runnerTemp = input(env, "RUNNER_TEMP") ||
    path.join(resolvedWorkspace, ".moonhermetic-ci");
  const summaryPath = summary || prComment
    ? path.join(runnerTemp, "moonhermetic-summary.md")
    : null;
  if (summaryPath) {
    args.push("--summary-file", summaryPath);
  }

  const requestedOutput = input(env, "INPUT_OUTPUT_FILE");
  const outputPath = requestedOutput === "-"
    ? null
    : resolveFromWorkspace(
      resolvedWorkspace,
      requestedOutput || defaultOutputName(audit, format),
    );

  return {
    actionPath: resolvedActionPath,
    workspace: resolvedWorkspace,
    audit,
    format,
    target,
    outputPath,
    summary,
    summaryPath,
    prComment,
    args,
  };
}
