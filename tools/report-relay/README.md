# Report relay

The bug icon on every screen of the app sends a report here, and this
Cloudflare Worker turns it into a GitHub issue ([ADR-0021](../../docs/adr/0021-in-app-reports.md)).
The GitHub token lives only in the Worker's secrets, never in the app.

What it does with a report:

- refuses it unless it is a bug, feature or suggestion with a title, within
  the size limits in `worker.js`, and its screenshot a PNG or JPEG under 3 MB;
- turns away an address sending more than 5 a minute;
- saves the screenshot on the `report-screenshots` branch, which it makes on
  first use with no history of `main`'s;
- opens an issue titled `Bug: …`, `Feature: …` or `Suggestion: …`, labelled
  `bug`, `enhancement` or `suggestion` and `from-app`, with the details, the
  screenshot, and what the app added (version, system, screen, languages).
  `@mentions` in a report are broken, so a report notifies no one.

It never edits, closes or comments on anything.

## Set it up (once)

1. **A GitHub token.** github.com → Settings → Developer settings →
   Fine-grained tokens → Generate new token:
   - Repository access: only `aaronified/fluenough`.
   - Permissions: **Issues: Read and write**, and **Contents: Read and
     write** (for the screenshots' branch). Nothing else.
   - An expiry you will remember to renew.
2. **A Cloudflare account**, free: <https://dash.cloudflare.com/sign-up>.
3. **Deploy**, from this directory:
   ```sh
   npx wrangler login
   npx wrangler deploy
   npx wrangler secret put GITHUB_TOKEN    # paste the token
   ```
   `deploy` prints the Worker's address, like
   `https://fluenough-reports.<you>.workers.dev`.
4. **Give the address to release builds:** the repository's Settings →
   Secrets and variables → Actions → **Variables** → New repository variable
   `REPORT_URL`, with that address. It is not a secret: the token is in the
   Worker, not the app. The next release's bug icon sends to it.

A build without `REPORT_URL`, such as `flutter run`, says reports cannot be
sent. To try reports from a debug build:
`flutter run --dart-define=REPORT_URL=https://fluenough-reports.<you>.workers.dev`.

## Test

```sh
node --test tools/report-relay/worker.test.mjs
```

Node's own runner, no packages: GitHub is a fake that records each call.
CI runs it.

## If it is abused

Anyone who finds the address can send reports, five a minute from each
address. They can only open issues, never change one. Lower `limit` in
`wrangler.toml` and deploy again, or `npx wrangler delete` to stop it; the
app then says reports cannot be sent. Revoke the token on GitHub if it ever
leaks.
