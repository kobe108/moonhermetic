export const MOONCAKES_OWNER = "kobe108";

export function createMooncakesCredential(moduleName, username, token) {
  if (!moduleName.startsWith(`${MOONCAKES_OWNER}/`)) {
    throw new Error(`module '${moduleName}' is not owned by ${MOONCAKES_OWNER}`);
  }
  if (username !== MOONCAKES_OWNER) {
    throw new Error(
      `Mooncakes username must be ${MOONCAKES_OWNER}; received '${username}'`,
    );
  }
  if (!token || token.trim().length < 16) {
    throw new Error("Mooncakes token is missing or too short");
  }
  return {
    token: token.trim(),
    username: MOONCAKES_OWNER,
  };
}

export function moonHome(home, configured) {
  if (configured) {
    return configured;
  }
  if (!home) {
    throw new Error("HOME or USERPROFILE is required");
  }
  return `${home.replaceAll("\\", "/").replace(/\/$/, "")}/.moon`;
}
