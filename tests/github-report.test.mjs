import assert from "node:assert/strict";
import test from "node:test";
import {
  COMMENT_MARKER,
  findManagedComment,
  pullRequestNumber,
  reportCommentBody,
} from "../scripts/github-report-lib.mjs";

test("detects pull request numbers only for pull request events", () => {
  assert.equal(
    pullRequestNumber("pull_request", { pull_request: { number: 42 } }),
    42,
  );
  assert.equal(
    pullRequestNumber("pull_request_target", { number: 7 }),
    7,
  );
  assert.equal(pullRequestNumber("push", { number: 7 }), null);
  assert.equal(pullRequestNumber("pull_request", {}), null);
});

test("adds a stable marker to managed comments", () => {
  const body = reportCommentBody("# Report\n\nNo findings.");
  assert.ok(body.startsWith(COMMENT_MARKER));
  assert.ok(body.endsWith("No findings.\n"));
});

test("updates an existing managed comment instead of adding another", () => {
  const managed = {
    id: 12,
    user: { type: "Bot" },
    body: `${COMMENT_MARKER}\nold report`,
  };
  assert.equal(
    findManagedComment([{ id: 1, user: { type: "User" }, body: "unrelated" }, managed]),
    managed,
  );
  assert.equal(
    findManagedComment([
      { id: 2, user: { type: "User" }, body: COMMENT_MARKER },
    ]),
    null,
  );
});
