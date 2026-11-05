import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { createActionPlan } from "./action-lib.mjs";

function appendOutput(name, value) {
  const outputFile = process.env.GITHUB_OUTPUT;
  if (outputFile) {
    fs.appendFileSync(outputFile, `${name}=${value}\n`, "utf8");
  }
}

function fail(message) {
  console.error(`::error title=MoonHermetic::${message}`);
  process.exit(2);
}

let plan;
try {
  plan = createActionPlan(process.env, {
    workspace: process.env.GITHUB_WORKSPACE,
    actionPath: process.env.ACTION_PATH,
  });
} catch (error) {
  fail(error instanceof Error ? error.message : String(error));
}

let stdout = "inherit";
let outputDescriptor;
if (plan.outputPath) {
  fs.mkdirSync(path.dirname(plan.outputPath), { recursive: true });
  outputDescriptor = fs.openSync(plan.outputPath, "w");
  stdout = outputDescriptor;
}

const result = spawnSync("moon", plan.args, {
  cwd: plan.actionPath,
  env: process.env,
  stdio: ["ignore", stdout, "inherit"],
});

if (outputDescriptor !== undefined) {
  fs.closeSync(outputDescriptor);
}

if (result.error) {
  fail(`could not run MoonBit: ${result.error.message}`);
}

if (plan.outputPath) {
  appendOutput("report-path", plan.outputPath);
}

const status = result.status ?? 1;
if (status === 0) {
  const destination = plan.outputPath
    ? `report written to ${plan.outputPath}`
    : "report written to the action log";
  console.log(`::notice title=MoonHermetic::${destination}`);
} else {
  console.error(
    `::error title=MoonHermetic::Analysis failed with exit code ${status}.`,
  );
}

process.exit(status);
