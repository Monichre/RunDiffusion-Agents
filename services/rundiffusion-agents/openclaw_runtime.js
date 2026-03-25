#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

const DEFAULT_RUNTIME_DIR = "/usr/local/lib/node_modules/openclaw";
const DEFAULT_PRISTINE_DIR = "/opt/openclaw-pristine/openclaw";
const DEFAULT_CONTROL_UI_CANDIDATES = [path.join("dist", "control-ui", "index.html")];
const DEFAULT_ENTRYPOINT_CANDIDATES = [
  "openclaw.mjs",
  path.join("dist", "entry.js"),
  path.join("dist", "index.js"),
];
const INVALID_CONTROL_UI_MARKERS = [
  {
    marker: "<title>OpenClaw Canvas</title>",
    reason: "OpenClaw control UI assets point at the Canvas (A2UI) shell instead of the browser Control UI.",
  },
  {
    marker: "a2ui.bundle.js",
    reason: "OpenClaw control UI assets load the Canvas (A2UI) bundle instead of the browser Control UI.",
  },
];

function resolveOptions(options = {}) {
  return {
    expectedVersion: String(
      options.expectedVersion ?? process.env.OPENCLAW_EXPECTED_VERSION ?? process.env.OPENCLAW_VERSION ?? "",
    ).trim(),
    runtimeDir: path.resolve(String(options.runtimeDir || process.env.OPENCLAW_RUNTIME_DIR || DEFAULT_RUNTIME_DIR)),
    pristineDir: path.resolve(
      String(options.pristineDir || process.env.OPENCLAW_PRISTINE_DIR || DEFAULT_PRISTINE_DIR),
    ),
    fs: options.fs || fs,
  };
}

function safeReadJson(fsImpl, filePath) {
  try {
    return JSON.parse(fsImpl.readFileSync(filePath, "utf8"));
  } catch (error) {
    return {
      __error: error instanceof Error ? error.message : String(error),
    };
  }
}

function safeReadText(fsImpl, filePath) {
  try {
    return {
      value: fsImpl.readFileSync(filePath, "utf8"),
      error: "",
    };
  } catch (error) {
    return {
      value: "",
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

function uniqueValues(values) {
  return [...new Set(values.filter(Boolean))];
}

function resolvePackageBinCandidates(packageJson) {
  if (!packageJson || packageJson.__error) {
    return [];
  }

  if (typeof packageJson.bin === "string") {
    return [packageJson.bin];
  }

  if (packageJson.bin && typeof packageJson.bin.openclaw === "string") {
    return [packageJson.bin.openclaw];
  }

  return [];
}

function resolveExistingPath(fsImpl, rootDir, candidates) {
  for (const relativePath of candidates) {
    const absolutePath = path.join(rootDir, relativePath);
    if (fsImpl.existsSync(absolutePath)) {
      return absolutePath;
    }
  }

  return "";
}

function validateControlUiIndex(fsImpl, controlUiIndexPath) {
  if (!controlUiIndexPath || !fsImpl.existsSync(controlUiIndexPath)) {
    return {
      ok: false,
      reasons: [],
    };
  }

  const { value, error } = safeReadText(fsImpl, controlUiIndexPath);
  if (error) {
    return {
      ok: false,
      reasons: [`OpenClaw control UI index is unreadable: ${error}`],
    };
  }

  const reasons = INVALID_CONTROL_UI_MARKERS.filter(({ marker }) => value.includes(marker)).map(
    ({ reason }) => reason,
  );

  return {
    ok: reasons.length === 0,
    reasons: uniqueValues(reasons),
  };
}

function buildRuntimeReport(options = {}) {
  const { expectedVersion, runtimeDir, pristineDir, fs: fsImpl } = resolveOptions(options);
  const packageJsonPath = path.join(runtimeDir, "package.json");
  const pristinePackageJsonPath = path.join(pristineDir, "package.json");
  const reasons = [];

  let currentVersion = "";
  if (!fsImpl.existsSync(runtimeDir)) {
    reasons.push(`OpenClaw runtime directory is missing: ${runtimeDir}`);
  }

  if (!fsImpl.existsSync(packageJsonPath)) {
    reasons.push(`OpenClaw package.json is missing: ${packageJsonPath}`);
  } else {
    const packageJson = safeReadJson(fsImpl, packageJsonPath);
    if (packageJson.__error) {
      reasons.push(`OpenClaw package.json is unreadable: ${packageJson.__error}`);
    } else {
      currentVersion = String(packageJson.version || "").trim();
      if (!currentVersion) {
        reasons.push("OpenClaw package.json does not declare a version.");
      }
    }
  }

  const packageJson = fsImpl.existsSync(packageJsonPath) ? safeReadJson(fsImpl, packageJsonPath) : null;
  const entrypointCandidates = uniqueValues([
    ...resolvePackageBinCandidates(packageJson),
    ...DEFAULT_ENTRYPOINT_CANDIDATES,
  ]);
  const controlUiCandidates = DEFAULT_CONTROL_UI_CANDIDATES;
  const entrypointPath = resolveExistingPath(fsImpl, runtimeDir, entrypointCandidates);
  const controlUiIndexPath = resolveExistingPath(fsImpl, runtimeDir, controlUiCandidates);
  const controlUiDir = controlUiIndexPath ? path.dirname(controlUiIndexPath) : path.join(runtimeDir, "dist");
  const controlUiValidation = validateControlUiIndex(fsImpl, controlUiIndexPath);

  if (expectedVersion && currentVersion && currentVersion !== expectedVersion) {
    reasons.push(`OpenClaw runtime version ${currentVersion} does not match pinned version ${expectedVersion}.`);
  }

  if (!entrypointPath) {
    reasons.push(`OpenClaw runtime entrypoint is missing under ${runtimeDir}.`);
  }

  if (!fsImpl.existsSync(controlUiIndexPath)) {
    reasons.push(
      `OpenClaw control UI assets are missing. Checked: ${controlUiCandidates
        .map((relativePath) => path.join(runtimeDir, relativePath))
        .join(", ")}`,
    );
  }
  reasons.push(...controlUiValidation.reasons);

  const pristineAvailable = fsImpl.existsSync(pristineDir) && fsImpl.existsSync(pristinePackageJsonPath);
  if (!pristineAvailable) {
    reasons.push(`Pristine OpenClaw runtime snapshot is missing: ${pristineDir}`);
  }

  return {
    ok: reasons.length === 0,
    expectedVersion,
    currentVersion,
    runtimeDir,
    pristineDir,
    entrypointPath,
    controlUiDir,
    controlUiIndexPath,
    controlUiIndexValid: controlUiValidation.ok,
    controlUiIndexInvalidReasons: controlUiValidation.reasons,
    pristineAvailable,
    reasons,
  };
}

function restoreRuntime(options = {}) {
  const { runtimeDir, pristineDir, fs: fsImpl } = resolveOptions(options);

  if (!fsImpl.existsSync(pristineDir)) {
    throw new Error(`Cannot restore OpenClaw runtime because ${pristineDir} does not exist.`);
  }

  fsImpl.rmSync(runtimeDir, { recursive: true, force: true });
  fsImpl.mkdirSync(path.dirname(runtimeDir), { recursive: true });
  fsImpl.cpSync(pristineDir, runtimeDir, { recursive: true, force: true });

  return buildRuntimeReport(options);
}

function runCli(argv = process.argv.slice(2), env = process.env) {
  const command = String(argv[0] || "check").trim().toLowerCase();
  const options = {
    expectedVersion: env.OPENCLAW_EXPECTED_VERSION || env.OPENCLAW_VERSION || "",
    runtimeDir: env.OPENCLAW_RUNTIME_DIR || DEFAULT_RUNTIME_DIR,
    pristineDir: env.OPENCLAW_PRISTINE_DIR || DEFAULT_PRISTINE_DIR,
  };

  if (command === "check") {
    const report = buildRuntimeReport(options);
    process.stdout.write(`${JSON.stringify(report)}\n`);
    process.exit(report.ok ? 0 : 1);
  }

  if (command === "repair") {
    const before = buildRuntimeReport(options);
    if (!before.ok) {
      process.stderr.write(`[openclaw-runtime] Repairing OpenClaw runtime: ${before.reasons.join(" | ")}\n`);
      const after = restoreRuntime(options);
      process.stdout.write(`${JSON.stringify(after)}\n`);
      process.exit(after.ok ? 0 : 1);
    }

    process.stdout.write(`${JSON.stringify(before)}\n`);
    process.exit(0);
  }

  process.stderr.write("Usage: openclaw_runtime.js <check|repair>\n");
  process.exit(64);
}

if (require.main === module) {
  runCli();
}

module.exports = {
  DEFAULT_PRISTINE_DIR,
  DEFAULT_RUNTIME_DIR,
  buildRuntimeReport,
  restoreRuntime,
  runCli,
};
