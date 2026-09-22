// The image ships exactly one certified OpenCode build, one Node runtime, one
// skills snapshot. Those properties live in Dockerfile ARG defaults, so they
// are asserted here rather than trusted to review: every tool pin must be an
// exact version (never a range or dist-tag), and the skills pin must be a
// full commit SHA.

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { describe, it } = require("node:test");

const REPO = path.join(__dirname, "..");
const dockerfile = fs.readFileSync(path.join(REPO, "Dockerfile"), "utf8");
const changelog = fs.readFileSync(path.join(REPO, "CHANGELOG.md"), "utf8");

const arg = (name) =>
  new RegExp(`^ARG ${name}=(.+)$`, "m").exec(dockerfile)?.[1]?.trim();

describe("image pins", () => {
  it("pins an exact OpenCode version", () => {
    const pin = arg("OPENCODE_VERSION");
    assert.ok(pin, "Dockerfile has no ARG OPENCODE_VERSION");
    assert.match(pin, /^\d+\.\d+\.\d+$/, `got '${pin}'`);
  });

  it("pins an exact Node version", () => {
    const pin = arg("NODE_VERSION");
    assert.ok(pin, "Dockerfile has no ARG NODE_VERSION");
    assert.match(pin, /^\d+\.\d+\.\d+$/, `got '${pin}'`);
  });

  it("pins every installed tool at an exact version", () => {
    for (const name of [
      "PPQ_PROXY_VERSION",
      "TSX_VERSION",
      "TTYD_VERSION",
      "YQ_VERSION",
      "OP_CLI_VERSION",
      "COSIGN_VERSION",
      "HAB_VERSION",
    ]) {
      const pin = arg(name);
      assert.ok(pin, `Dockerfile has no ARG ${name}`);
      assert.doesNotMatch(
        pin,
        /[@~^><]|\blatest\b|\*/,
        `${name} must be an exact pin, got '${pin}'`,
      );
    }
  });

  it("pins the skills snapshot to a full commit SHA", () => {
    const pin = arg("SKILLS_REF");
    assert.ok(pin, "Dockerfile has no ARG SKILLS_REF");
    assert.match(pin, /^[0-9a-f]{40}$/, `SKILLS_REF must be a 40-hex SHA, got '${pin}'`);
  });

  it("installs npm packages only through exact pins", () => {
    const installBlock = /RUN npm install -g[\s\S]*?ppq-private-mode@[\s\S]*?\n/.exec(
      dockerfile,
    )?.[0];
    assert.ok(installBlock, "no global npm install block found");
    for (const pinned of installBlock.matchAll(/([\w@/.-]+)@([\w.-]+)/g)) {
      const [, pkg, version] = pinned;
      if (pkg === "npm" || pkg === "node") continue;
      assert.doesNotMatch(
        version,
        /[@~^]|\blatest\b|\*/,
        `${pkg} must be installed at an exact version, got '@${version}'`,
      );
    }
    // Unpinned entries are allowed only for the two that are intentional.
    const unpinned = [...installBlock.matchAll(/^\s{8}(?![\s-])([\w@/.-]+)\s*$/gm)].map(
      (m) => m[1],
    );
    assert.deepEqual(
      unpinned.filter((p) => p !== "prettier"),
      [],
      "only prettier may float",
    );
  });

  it("updates the changelog top section for the current release", () => {
    assert.match(changelog, /^## 1\.1\.0$/m, "changelog is missing its 1.1.0 section");
  });
});
