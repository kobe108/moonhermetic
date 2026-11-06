export const COMMENT_MARKER = "<!-- moonhermetic-report -->";

export function pullRequestNumber(eventName, event) {
  if (eventName !== "pull_request" && eventName !== "pull_request_target") {
    return null;
  }
  const number = event?.pull_request?.number ?? event?.number;
  return Number.isInteger(number) ? number : null;
}

export function reportCommentBody(summary) {
  return `${COMMENT_MARKER}\n${summary.trim()}\n`;
}

export function findManagedComment(comments) {
  return comments.find((comment) => {
    return comment.user?.type === "Bot" &&
      typeof comment.body === "string" &&
      comment.body.includes(COMMENT_MARKER);
  }) ?? null;
}
