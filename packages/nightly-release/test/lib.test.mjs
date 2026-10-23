import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  greenState,
  lastPackageTag,
  localDate,
  planPackages,
  readBaseVersion,
  releasesToPrune,
  renderVersion,
  validateConfig,
} from "../lib.mjs";

const LA = "America/Los_Angeles";

test("localDate follows Los Angeles DST, not UTC", () => {
  // 2026-10-24 07:30Z is 00:30 PDT on the 24th.
  assert.equal(localDate(new Date("2026-10-24T07:30:00Z"), LA), "20261024");
  // 2026-12-02 07:30Z is 23:30 PST on the 1st: still the previous local day.
  assert.equal(localDate(new Date("2026-12-02T07:30:00Z"), LA), "20261201");
  assert.equal(localDate(new Date("2026-12-02T08:30:00Z"), LA), "20261202");
});

test("readBaseVersion reads mix.exs and package.json", () => {
  assert.equal(readBaseVersion('def project do\n  [app: :voice_converse,\n   version: "0.1.0",'), "0.1.0");
  assert.equal(readBaseVersion('{\n  "name": "x",\n  "version": "2.3.4"\n}'), "2.3.4");
  assert.throws(() => readBaseVersion("nothing here"), /no version/);
});

test("renderVersion fills base, date and short sha", () => {
  const sha = "0123456789abcdef0123456789abcdef01234567";
  assert.equal(renderVersion("{base}-nightly.{date}", { base: "0.1.0", date: "20261024", sha }), "0.1.0-nightly.20261024");
  assert.equal(renderVersion("{base}-nightly.{sha7}", { base: "0.0.9", date: "20261024", sha }), "0.0.9-nightly.0123456");
});

test("lastPackageTag picks the newest earlier tag of that package only", () => {
  const tags = ["nightly/aiur/20261020", "nightly/aiur/20261022", "nightly/aiur-image/20261023", "nightly/aiur/20261024", "nightly-20261022", "nightly/aiur/latest"];
  assert.equal(lastPackageTag(tags, "aiur", "20261024"), "nightly/aiur/20261022");
  assert.equal(lastPackageTag(tags, "voice_converse", "20261024"), null);
});

test("greenState: newest run per workflow decides", () => {
  const run = (created_at, status, conclusion) => ({ created_at, status, conclusion, html_url: "u" });
  assert.equal(greenState({ "ci.yml": [run("2026-10-24T01:00:00Z", "completed", "success")] }).state, "green");
  assert.equal(greenState({ "ci.yml": [] }).state, "none");
  assert.equal(greenState({ "ci.yml": [run("2026-10-24T01:00:00Z", "in_progress", null)] }).state, "pending");
  // A newer red run outranks an older green one at the same sha.
  const mixed = [run("2026-10-24T01:00:00Z", "completed", "success"), run("2026-10-24T02:00:00Z", "completed", "failure")];
  assert.equal(greenState({ "ci.yml": mixed }).state, "red");
  // Red in any required workflow is red even if another is still running.
  assert.equal(
    greenState({ "a.yml": [run("2026-10-24T01:00:00Z", "in_progress", null)], "b.yml": [run("2026-10-24T01:00:00Z", "completed", "cancelled")] }).state,
    "red",
  );
});

test("validateConfig rejects bad entries and accepts the shipped config", () => {
  const shipped = JSON.parse(readFileSync(new URL("../../../.github/nightly-release.json", import.meta.url), "utf8"));
  assert.deepEqual(validateConfig(shipped), []);
  const errors = validateConfig({
    timezone: LA,
    branch: "main",
    required_workflows: ["ci.yml"],
    packages: [
      { name: "a", kind: "npm", paths: ["x"], version_file: "v" },
      { name: "b", kind: "dispatch", paths: [], version_file: "v" },
      { name: "b", kind: "docker", paths: ["x"], version_file: "v" },
    ],
  });
  assert.ok(errors.some((e) => e.includes("(a): kind")));
  assert.ok(errors.some((e) => e.includes("(b): paths")));
  assert.ok(errors.some((e) => e.includes("(b): dispatch needs workflow")));
  assert.ok(errors.some((e) => e.includes("(b): duplicate")));
  assert.ok(errors.some((e) => e.includes("(b): docker needs image")));
});

test("planPackages releases only changed packages, once per date", () => {
  const sha = "0123456789abcdef0123456789abcdef01234567";
  const config = {
    packages: [
      { name: "changed", kind: "git-tag", paths: ["a"], version_file: "a/mix.exs" },
      { name: "same", kind: "git-tag", paths: ["b"], version_file: "b/mix.exs" },
      { name: "new", kind: "git-tag", paths: ["c"], version_file: "c/mix.exs", version: "{base}-n.{sha7}" },
      { name: "done", kind: "git-tag", paths: ["d"], version_file: "d/mix.exs" },
    ],
  };
  const tags = ["nightly/changed/20261020", "nightly/same/20261021", "nightly/done/20261020", "nightly/done/20261024"];
  const calls = [];
  const plan = planPackages({
    config,
    tags,
    date: "20261024",
    sha,
    git: { changed: (from, _sha, paths) => (calls.push([from, paths]), from === "nightly/changed/20261020") },
    baseVersion: () => "1.2.3",
  });
  const by = Object.fromEntries(plan.map((e) => [e.pkg.name, e]));
  assert.equal(by.changed.action, "release");
  assert.equal(by.changed.tag, "nightly/changed/20261024");
  assert.equal(by.changed.version, "1.2.3-nightly.20261024");
  assert.equal(by.same.action, "skip");
  assert.equal(by.new.action, "release");
  assert.equal(by.new.version, "1.2.3-n.0123456");
  assert.equal(by.done.action, "skip");
  assert.match(by.done.reason, /already released today/);
  // The diff runs against each package's own last tag and paths.
  assert.deepEqual(calls, [["nightly/changed/20261020", ["a"]], ["nightly/same/20261021", ["b"]]]);
});

test("releasesToPrune keeps the newest N of one package", () => {
  const tags = ["nightly/a/20261022", "nightly/a/20261020", "nightly/a/20261021", "nightly/b/20261001", "v0.0.8"];
  assert.deepEqual(releasesToPrune(tags, "a", 2), ["nightly/a/20261020"]);
  assert.deepEqual(releasesToPrune(tags, "b", 2), []);
});
