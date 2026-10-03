// The relay between the app's bug icon and GitHub issues (ADR-0021).
//
// The app posts a report here: its kind, title, details, what the app adds
// (version, screen, languages) and a screenshot. This Worker holds the GitHub
// token, as a Cloudflare secret, so the app never does. It only ever does
// two things with it: save the screenshot on the report-screenshots branch,
// and open an issue. It cannot be made to edit, close or comment.
//
// Setup and limits: README.md beside this file.

const KINDS = {
  bug: { label: "bug", prefix: "Bug" },
  feature: { label: "enhancement", prefix: "Feature" },
  suggestion: { label: "suggestion", prefix: "Suggestion" },
};
const FROM_APP = "from-app";
const BRANCH = "report-screenshots";

export const LIMITS = {
  title: 120,
  details: 4000,
  contextEntries: 12,
  contextKey: 40,
  contextValue: 300,
  screenshotBytes: 3_000_000,
};

export default {
  async fetch(request, env) {
    if (request.method !== "POST") return reply(405, { error: "POST only" });
    if (env.LIMITER) {
      const key = request.headers.get("CF-Connecting-IP") ?? "unknown";
      const { success } = await env.LIMITER.limit({ key });
      if (!success) return reply(429, { error: "too many reports, try later" });
    }
    let report;
    try {
      report = checked(await request.json());
    } catch (error) {
      return reply(400, { error: String(error.message ?? error) });
    }
    try {
      const github = client(env);
      const image = report.screenshot
        ? await saveScreenshot(github, env.REPO, report.screenshot)
        : null;
      const issue = await openIssue(github, env.REPO, report, image);
      return reply(201, { url: issue.html_url, number: issue.number });
    } catch (error) {
      console.error(error);
      return reply(502, { error: "GitHub did not take the report" });
    }
  },
};

/** The report, trimmed and bounded, or an Error saying what is wrong. */
export function checked(body) {
  if (body === null || typeof body !== "object") throw new Error("not a report");
  const kind = KINDS[body.kind];
  if (!kind) throw new Error("kind must be bug, feature or suggestion");
  const title = text(body.title, "title", LIMITS.title).replace(/\s+/g, " ");
  if (!title) throw new Error("title is empty");
  const details = text(body.details ?? "", "details", LIMITS.details);
  const context = {};
  const entries = Object.entries(body.context ?? {});
  if (entries.length > LIMITS.contextEntries) throw new Error("context too long");
  for (const [key, value] of entries) {
    context[text(key, "context key", LIMITS.contextKey)] = text(
      value,
      "context value",
      LIMITS.contextValue,
    );
  }
  const screenshot =
    body.screenshot == null ? null : image(body.screenshot);
  return { kind, title, details, context, screenshot };
}

function text(value, name, max) {
  if (typeof value !== "string") throw new Error(`${name} must be text`);
  const trimmed = value.trim();
  if (trimmed.length > max) throw new Error(`${name} is over ${max} characters`);
  return trimmed;
}

/** A PNG or JPEG, from base64: its bytes and its extension. */
function image(base64) {
  if (typeof base64 !== "string") throw new Error("screenshot must be base64");
  let bytes;
  try {
    bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
  } catch {
    throw new Error("screenshot is not base64");
  }
  if (bytes.length > LIMITS.screenshotBytes) throw new Error("screenshot too big");
  const png = [0x89, 0x50, 0x4e, 0x47].every((b, i) => bytes[i] === b);
  const jpeg = [0xff, 0xd8, 0xff].every((b, i) => bytes[i] === b);
  if (!png && !jpeg) throw new Error("screenshot must be PNG or JPEG");
  return { base64, extension: png ? "png" : "jpg" };
}

/** Calls GitHub's REST API with the token; throws on any failure. */
function client(env) {
  return async (method, path, body) => {
    const response = await fetch(`https://api.github.com${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${env.GITHUB_TOKEN}`,
        Accept: "application/vnd.github+json",
        "Content-Type": "application/json",
        "User-Agent": "fluenough-report-relay",
        "X-GitHub-Api-Version": "2022-11-28",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!response.ok) {
      const error = new Error(`${method} ${path}: ${response.status}`);
      error.status = response.status;
      throw error;
    }
    return response.json();
  };
}

/** Saves the screenshot on its own branch; returns the address it shows at. */
export async function saveScreenshot(github, repo, screenshot) {
  await ensureBranch(github, repo);
  const month = new Date().toISOString().slice(0, 7);
  const path = `${month}/${crypto.randomUUID()}.${screenshot.extension}`;
  await github("PUT", `/repos/${repo}/contents/${path}`, {
    message: "Screenshot for a report from the app",
    content: screenshot.base64,
    branch: BRANCH,
  });
  return `https://raw.githubusercontent.com/${repo}/${BRANCH}/${path}`;
}

/** Makes the screenshots' branch on first use, with no history of main's. */
async function ensureBranch(github, repo) {
  try {
    await github("GET", `/repos/${repo}/git/ref/heads/${BRANCH}`);
    return;
  } catch (error) {
    if (error.status !== 404) throw error;
  }
  const tree = await github("POST", `/repos/${repo}/git/trees`, {
    tree: [
      {
        path: "README.md",
        mode: "100644",
        type: "blob",
        content:
          "Screenshots sent with reports from the app's bug icon " +
          "(docs/adr/0021-in-app-reports.md on main).\n",
      },
    ],
  });
  const commit = await github("POST", `/repos/${repo}/git/commits`, {
    message: "Start the branch for report screenshots",
    tree: tree.sha,
    parents: [],
  });
  await github("POST", `/repos/${repo}/git/refs`, {
    ref: `refs/heads/${BRANCH}`,
    sha: commit.sha,
  });
}

/** Opens the issue, labelled; without labels if GitHub refuses them. */
async function openIssue(github, repo, report, image) {
  const issue = {
    title: `${report.kind.prefix}: ${quiet(report.title)}`,
    body: issueBody(report, image),
  };
  try {
    return await github("POST", `/repos/${repo}/issues`, {
      ...issue,
      labels: [report.kind.label, FROM_APP],
    });
  } catch (error) {
    if (error.status !== 422) throw error;
    return github("POST", `/repos/${repo}/issues`, issue);
  }
}

/** The issue's text: the details, the screenshot, then what the app added. */
export function issueBody(report, image) {
  const rows = Object.entries(report.context).map(
    ([key, value]) => `| ${cell(key)} | ${cell(value)} |`,
  );
  return [
    report.details ? quiet(report.details) : "_No details given._",
    image ? `\n![Screenshot](${image})` : "",
    rows.length
      ? `\n<details><summary>From the app</summary>\n\n| | |\n|---|---|\n${rows.join("\n")}\n\n</details>`
      : "",
    "\n<sub>Sent with the app's bug icon.</sub>",
  ].join("\n");
}

/** No @mentions: a report must not notify anyone it names. */
export function quiet(value) {
  return value.replace(/@(?=[A-Za-z0-9])/g, "@​");
}

function cell(value) {
  return quiet(value).replace(/\|/g, "\\|").replace(/\s+/g, " ");
}

function reply(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
