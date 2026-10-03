// Tests for the report relay. Run with
// `node --test tools/report-relay/worker.test.mjs`:
// Node's own runner, no packages. GitHub is a fake that records calls.
import assert from "node:assert/strict";
import { test } from "node:test";

import worker, { checked, issueBody, quiet } from "./worker.js";

const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function post(body, headers = {}) {
  return new Request("https://relay.example/", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

/** A fake GitHub: answers by route, and records each call. */
function fakeGitHub({ branch = true, labels = true } = {}) {
  const calls = [];
  globalThis.fetch = async (url, init) => {
    const path = new URL(url).pathname;
    const body = init.body ? JSON.parse(init.body) : undefined;
    calls.push({ method: init.method, path, body, auth: init.headers.Authorization });
    const ok = (json, status = 200) =>
      new Response(JSON.stringify(json), { status });
    if (path.endsWith("/git/ref/heads/report-screenshots")) {
      return branch ? ok({}) : ok({ message: "Not Found" }, 404);
    }
    if (path.endsWith("/git/trees")) return ok({ sha: "tree1" }, 201);
    if (path.endsWith("/git/commits")) return ok({ sha: "commit1" }, 201);
    if (path.endsWith("/git/refs")) return ok({}, 201);
    if (path.includes("/contents/")) return ok({}, 201);
    if (path.endsWith("/issues")) {
      if (!labels && body.labels) return ok({ message: "Validation" }, 422);
      return ok({ html_url: "https://github.com/o/r/issues/7", number: 7 }, 201);
    }
    return ok({ message: "unexpected" }, 500);
  };
  return calls;
}

const env = { REPO: "o/r", GITHUB_TOKEN: "secret" };
const report = {
  kind: "bug",
  title: "  The card   shows twice ",
  details: "Seen on @someone's phone",
  context: { App: "fluenough 0.2.0", Screen: "/drill" },
  screenshot: PNG.toString("base64"),
};

test("a report becomes a labelled issue, its screenshot on its branch", async () => {
  const calls = fakeGitHub();
  const response = await worker.fetch(post(report), env);
  assert.equal(response.status, 201);
  assert.deepEqual(await response.json(), {
    url: "https://github.com/o/r/issues/7",
    number: 7,
  });
  const upload = calls.find((c) => c.method === "PUT");
  assert.match(upload.path, /^\/repos\/o\/r\/contents\/\d{4}-\d{2}\/[0-9a-f-]+\.png$/);
  assert.equal(upload.body.branch, "report-screenshots");
  const issue = calls.find((c) => c.path === "/repos/o/r/issues");
  assert.equal(issue.body.title, "Bug: The card shows twice");
  assert.deepEqual(issue.body.labels, ["bug", "from-app"]);
  assert.match(issue.body.body, /!\[Screenshot\]\(https:\/\/raw\.githubusercontent\.com\/o\/r\/report-screenshots\//);
  assert.ok(calls.every((c) => c.auth === "Bearer secret"));
  // Only reads, the screenshot and the issue: nothing edits or closes.
  assert.deepEqual(
    calls.map((c) => c.method).sort(),
    ["GET", "POST", "PUT"],
  );
});

test("the branch is made on first use, with no parent", async () => {
  const calls = fakeGitHub({ branch: false });
  const response = await worker.fetch(post(report), env);
  assert.equal(response.status, 201);
  const commit = calls.find((c) => c.path.endsWith("/git/commits"));
  assert.deepEqual(commit.body.parents, []);
  const ref = calls.find((c) => c.path.endsWith("/git/refs"));
  assert.equal(ref.body.ref, "refs/heads/report-screenshots");
});

test("a report without a screenshot touches no branch", async () => {
  const calls = fakeGitHub();
  const { screenshot, ...plain } = report;
  const response = await worker.fetch(post({ ...plain, kind: "feature" }), env);
  assert.equal(response.status, 201);
  assert.deepEqual(calls.map((c) => c.path), ["/repos/o/r/issues"]);
  assert.deepEqual(calls[0].body.labels, ["enhancement", "from-app"]);
});

test("labels GitHub refuses are left off rather than losing the report", async () => {
  const calls = fakeGitHub({ labels: false });
  const response = await worker.fetch(post({ ...report, screenshot: null }), env);
  assert.equal(response.status, 201);
  assert.equal(calls.length, 2);
  assert.equal(calls[1].body.labels, undefined);
});

test("bad reports are refused before GitHub is called", async () => {
  for (const [body, needle] of [
    [{ ...report, kind: "praise" }, "kind"],
    [{ ...report, title: "   " }, "title is empty"],
    [{ ...report, title: "x".repeat(121) }, "title is over"],
    [{ ...report, details: 3 }, "details must be text"],
    [{ ...report, screenshot: Buffer.from("GIF89a").toString("base64") }, "PNG or JPEG"],
    [{ ...report, screenshot: "%%%" }, "not base64"],
    [{ ...report, context: Object.fromEntries(Array.from({ length: 13 }, (_, i) => [`k${i}`, "v"])) }, "context too long"],
  ]) {
    const calls = fakeGitHub();
    const response = await worker.fetch(post(body), env);
    assert.equal(response.status, 400, needle);
    assert.match((await response.json()).error, new RegExp(needle));
    assert.equal(calls.length, 0, needle);
  }
});

test("only POST, and a sender over the limit is turned away", async () => {
  fakeGitHub();
  const get = await worker.fetch(new Request("https://relay.example/"), env);
  assert.equal(get.status, 405);
  const limited = await worker.fetch(post(report), {
    ...env,
    LIMITER: { limit: async () => ({ success: false }) },
  });
  assert.equal(limited.status, 429);
});

test("GitHub failing is a 502, not a crash", async () => {
  globalThis.fetch = async () => new Response("{}", { status: 500 });
  const original = console.error;
  console.error = () => {};
  try {
    const response = await worker.fetch(post(report), env);
    assert.equal(response.status, 502);
  } finally {
    console.error = original;
  }
});

test("a report notifies no one it names, and keeps its table whole", () => {
  assert.equal(quiet("ask @aaronified"), "ask @​aaronified");
  const body = issueBody(
    checked({ ...report, context: { "Show|ing": "a | b\nc" }, screenshot: null }),
    null,
  );
  assert.match(body, /@​someone/);
  assert.match(body, /\| Show\\\|ing \| a \\\| b c \|/);
});
