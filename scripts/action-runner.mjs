import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { createActionPlan } from "./action-lib.mjs";
import {
  findManagedComment,
  pullRequestNumber,
  reportCommentBody,
} from "./github-report-lib.mjs";

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

async function githubRequest(route, init = {}) {
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    throw new Error("GITHUB_TOKEN is required to comment on a pull request");
  }
  const apiUrl = process.env.GITHUB_API_URL || "https://api.github.com";
  const response = await fetch(`${apiUrl}${route}`, {
    ...init,
    headers: {
      accept: "application/vnd.github+json",
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
      "user-agent": "MoonHermetic-GitHub-Action",
      ...init.headers,
    },
  });
  if (!response.ok) {
    throw new Error(`GitHub API ${route} failed with HTTP ${response.status}`);
  }
  return response.json();
}

async function postPullRequestComment(summary) {
  const eventPath = process.env.GITHUB_EVENT_PATH;
  if (!eventPath || !fs.existsSync(eventPath)) {
    throw new Error("GITHUB_EVENT_PATH is missing; cannot locate the pull request");
  }
  const event = JSON.parse(fs.readFileSync(eventPath, "utf8"));
  const number = pullRequestNumber(process.env.GITHUB_EVENT_NAME, event);
  if (!number) {
    console.log(
      "::notice title=MoonHermetic::PR comment skipped because this is not a pull request event.",
    );
    return;
  }
  const repository = process.env.GITHUB_REPOSITORY;
  if (!repository) {
    throw new Error("GITHUB_REPOSITORY is required to comment on a pull request");
  }

  const commentsRoute =
    `/repos/${repository}/issues/${number}/comments?per_page=100`;
  const comments = await githubRequest(commentsRoute);
  const body = reportCommentBody(summary);
  const existing = findManagedComment(comments);
  if (existing) {
    await githubRequest(
      `/repos/${repository}/issues/comments/${existing.id}`,
      {
        method: "PATCH",
        body: JSON.stringify({ body }),
      },
    );
    console.log(
      `::notice title=MoonHermetic::Updated pull request comment #${existing.id}.`,
    );
  } else {
    await githubRequest(`/repos/${repository}/issues/${number}/comments`, {
      method: "POST",
      body: JSON.stringify({ body }),
    });
    console.log("::notice title=MoonHermetic::Created pull request comment.");
  }
}

function readSummary(summaryPath) {
  if (!summaryPath) {
    return "";
  }
  if (!fs.existsSync(summaryPath)) {
    throw new Error(`summary file was not generated: ${summaryPath}`);
  }
  return fs.readFileSync(summaryPath, "utf8");
}

async function main() {
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

  const binary = (process.env.MOONHERMETIC_BINARY ?? "").trim();
  const useBinary = binary !== "";
  const result = spawnSync(
    useBinary ? binary : "moon",
    useBinary ? plan.args.slice(3) : plan.args,
    {
      cwd: useBinary ? plan.workspace : plan.actionPath,
      env: process.env,
      stdio: ["ignore", stdout, "inherit"],
    },
  );

  if (outputDescriptor !== undefined) {
    fs.closeSync(outputDescriptor);
  }
  if (result.error) {
    fail(`could not run MoonHermetic: ${result.error.message}`);
  }

  if (plan.outputPath) {
    appendOutput("report-path", plan.outputPath);
  }
  if (plan.summaryPath) {
    appendOutput("summary-path", plan.summaryPath);
  }

  let summary = "";
  try {
    summary = readSummary(plan.summaryPath);
  } catch (error) {
    fail(error instanceof Error ? error.message : String(error));
  }
  if (plan.summary && summary) {
    const stepSummary = process.env.GITHUB_STEP_SUMMARY;
    if (stepSummary) {
      fs.appendFileSync(stepSummary, `\n${summary.trim()}\n`, "utf8");
      console.log("::notice title=MoonHermetic::GitHub job summary updated.");
    }
  }
  if (plan.prComment && summary) {
    try {
      await postPullRequestComment(summary);
    } catch (error) {
      fail(error instanceof Error ? error.message : String(error));
    }
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
}

await main();
