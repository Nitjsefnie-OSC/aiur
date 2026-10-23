#!/usr/bin/env node
// Cut one nightly per local date from a green commit on the release branch.
//
//   nightly-release.mjs --config <file> [--sha <40-char sha>] [--dry-run]
//
// Runs inside a full clone of the target repo (fetch-depth 0, tags fetched),
// with `gh` authenticated by GH_TOKEN and GITHUB_REPOSITORY set. See README.md.

import { execFileSync } from "node:child_process";
import { appendFileSync, readFileSync, writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import {
  assertSha,
  dayTag,
  greenState,
  localDate,
  planPackages,
  readBaseVersion,
  releasesToPrune,
  validateConfig,
} from "./lib.mjs";

const WAIT_MS = Number(process.env.NIGHTLY_WAIT_MS ?? 10 * 60 * 1000);
const POLL_MS = 30 * 1000;

function parseArgs(argv) {
  const out = { dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--dry-run") out.dryRun = true;
    else if (argv[i] === "--config") out.config = argv[++i];
    else if (argv[i] === "--sha") out.sha = argv[++i];
    else throw new Error(`unknown argument: ${argv[i]}`);
  }
  if (!out.config) throw new Error("--config is required");
  return out;
}

const run = (cmd, args, opts = {}) => execFileSync(cmd, args, { encoding: "utf8", ...opts }).trim();
const git = (...args) => run("git", args);
const gh = (...args) => run("gh", args);
const repo = () => {
  const r = process.env.GITHUB_REPOSITORY;
  if (!r) throw new Error("GITHUB_REPOSITORY is not set");
  return r;
};
const summary = (line) => {
  console.log(line);
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${line}\n`);
};

function workflowRuns(workflow, sha, branch) {
  const out = gh(
    "api",
    `repos/${repo()}/actions/workflows/${workflow}/runs?head_sha=${sha}&branch=${branch}&per_page=50`,
    "--jq",
    "[.workflow_runs[] | {status, conclusion, created_at, html_url}]",
  );
  return JSON.parse(out || "[]");
}

async function waitForGreen(config, sha) {
  const deadline = Date.now() + WAIT_MS;
  for (;;) {
    const runs = Object.fromEntries(config.required_workflows.map((w) => [w, workflowRuns(w, sha, config.branch)]));
    const state = greenState(runs);
    if (state.state !== "pending" || Date.now() >= deadline) return state;
    console.log(`waiting: ${state.reason}`);
    await new Promise((r) => setTimeout(r, POLL_MS));
  }
}

function changed(fromTag, sha, paths) {
  try {
    git("merge-base", "--is-ancestor", fromTag, sha);
  } catch {
    return true;
  }
  try {
    git("diff", "--quiet", fromTag, sha, "--", ...paths);
    return false;
  } catch {
    return true;
  }
}

function notes(entry, sha) {
  const range = entry.previous ? [`${entry.previous}..${sha}`] : ["-n", "50", sha];
  const log = git("log", "--no-merges", "--format=- %s (%h)", ...range, "--", ...entry.pkg.paths);
  const since = entry.previous ? `since \`${entry.previous}\`` : "(first nightly; last 50 commits)";
  return `Nightly ${entry.version} of \`${entry.pkg.name}\` from ${sha}.\n\nChanges ${since}:\n\n${log || "- (none)"}\n`;
}

// Kind actions. Each throws on failure; the caller rolls the tag back.
const actions = {
  dispatch(entry) {
    const args = ["workflow", "run", entry.pkg.workflow, "--repo", repo(), "--ref", entry.tag];
    for (const [k, v] of Object.entries(entry.pkg.inputs ?? {})) args.push("-f", `${k}=${v}`);
    gh(...args);
    return `dispatched ${entry.pkg.workflow} on ${entry.tag}`;
  },
  docker(entry, sha) {
    const source = `${entry.pkg.image}:${sha}`;
    run("docker", ["buildx", "imagetools", "inspect", source], { stdio: "pipe" });
    run("docker", ["buildx", "imagetools", "create", "-t", `${entry.pkg.image}:nightly`, "-t", `${entry.pkg.image}:${entry.version}`, source]);
    return `tagged ${source} as :nightly and :${entry.version}`;
  },
  "git-tag"() {
    return "tag only";
  },
};

function release(entry, sha) {
  gh("api", "-X", "POST", `repos/${repo()}/git/refs`, "-f", `ref=refs/tags/${entry.tag}`, "-f", `sha=${sha}`);
  try {
    const detail = actions[entry.pkg.kind](entry, sha);
    if (entry.pkg.prerelease !== false) {
      const file = path.join(mkdtempSync(path.join(tmpdir(), "nightly-")), "notes.md");
      writeFileSync(file, notes(entry, sha));
      gh("release", "create", entry.tag, "--repo", repo(), "--verify-tag", "--prerelease", "--latest=false", "--title", `${entry.pkg.name} ${entry.version}`, "--notes-file", file);
    }
    return detail;
  } catch (error) {
    // Roll the tag back so a later trigger retries this package.
    try {
      gh("api", "-X", "DELETE", `repos/${repo()}/git/refs/tags/${entry.tag}`);
    } catch {
      console.error(`could not remove ${entry.tag}; delete it by hand to retry`);
    }
    throw error;
  }
}

function prune(config, entry) {
  const retain = config.retain ?? 14;
  const tags = gh("release", "list", "--repo", repo(), "--limit", "200", "--json", "tagName", "--jq", ".[].tagName").split("\n");
  for (const tag of releasesToPrune(tags.filter(Boolean), entry.pkg.name, retain)) {
    gh("release", "delete", tag, "--repo", repo(), "--yes"); // the tag stays as the change baseline
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const config = JSON.parse(readFileSync(args.config, "utf8"));
  const errors = validateConfig(config);
  if (errors.length) throw new Error(`invalid config ${args.config}:\n  ${errors.join("\n  ")}`);

  const now = process.env.NIGHTLY_NOW ? new Date(process.env.NIGHTLY_NOW) : new Date();
  const date = localDate(now, config.timezone);
  git("fetch", "--quiet", "--tags", "--force", "origin", config.branch);
  const tags = git("tag", "--list", "nightly*").split("\n").filter(Boolean);

  summary(`## Nightly ${date} (${config.timezone})${args.dryRun ? " — dry run" : ""}`);
  if (tags.includes(dayTag(date))) {
    summary(`\`${dayTag(date)}\` exists; today's nightly is done.`);
    return 0;
  }

  const sha = assertSha(args.sha || git("rev-parse", `origin/${config.branch}`));
  try {
    git("merge-base", "--is-ancestor", sha, `origin/${config.branch}`);
  } catch {
    throw new Error(`${sha} is not on ${config.branch}`);
  }
  const green = await waitForGreen(config, sha);
  summary(`Candidate \`${sha}\`: **${green.state}** — ${green.reason}`);
  if (green.state !== "green") return 0;

  const plan = planPackages({
    config,
    tags,
    date,
    sha,
    git: { changed },
    baseVersion: (file) => readBaseVersion(git("show", `${sha}:${file}`)),
  });

  summary("\n| package | kind | version | action | detail |\n| --- | --- | --- | --- | --- |");
  let failed = 0;
  for (const entry of plan) {
    let detail = entry.reason;
    let action = entry.action;
    if (entry.action === "release" && args.dryRun) {
      action = "would release";
    } else if (entry.action === "release") {
      try {
        detail = release(entry, sha);
        prune(config, entry);
      } catch (error) {
        failed++;
        action = "FAILED";
        detail = String(error.stderr || error.message).split("\n")[0];
        console.error(`::error::${entry.pkg.name}: ${error.stderr || error.message}`);
      }
    }
    summary(`| ${entry.pkg.name} | ${entry.pkg.kind} | ${entry.version} | ${action} | ${detail} |`);
  }

  if (args.dryRun) return 0;
  if (failed) {
    summary(`\n${failed} package(s) failed; \`${dayTag(date)}\` withheld so the next trigger retries them.`);
    return 1;
  }
  gh("api", "-X", "POST", `repos/${repo()}/git/refs`, "-f", `ref=refs/tags/${dayTag(date)}`, "-f", `sha=${sha}`);
  summary(`\nCreated \`${dayTag(date)}\` at \`${sha}\`.`);
  return 0;
}

main().then(
  (code) => process.exit(code),
  (error) => {
    console.error(`nightly-release: ${error.message}`);
    process.exit(1);
  },
);
