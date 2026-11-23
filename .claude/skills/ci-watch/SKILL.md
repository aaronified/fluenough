---
name: ci-watch
description: Use whenever you wait for CI, a merge, a review or any background job on a pull request. Rules so that a failed check, a dead watcher or a finished agent is never missed (owner, 2026-11-23).
---

# Watching CI and background work

Owner, 2026-11-23: "You have been doing this repeatedly. Fix your system prompts and skills." The failure: a watcher reported "NOT green" and the orchestrator did not read it for 12 hours, because a notification that only said a background command "completed" was taken as a result.

Rules:

1. **A "completed" notification is not a result.** It only says a process exited. Always read the task's output file (or ask the API) before saying anything about the outcome. For a launcher started with `nohup ... &` or a trailing `&`, "completed" fires at once and means nothing.
2. **Start watchers directly with `run_in_background` on the watcher command itself** (no `nohup`, no `&`, no wrapper), so that its completion notification is its result. Then read its output the moment it arrives.
3. **Never say "I'll hear back" or "I'll check" unless a live watcher exists.** Verify it (`pgrep -f` or the task list) in the same turn. If none is running, start one or poll in the foreground.
4. **Check the first round of any loop or retry** before leaving it alone. A loop whose first round changed nothing will never succeed. Read why it failed.
5. **After any push by an agent or by you, the next action is a CI read**, not a status message: list the head sha's check runs and report green, red (which check) or pending, with the time.
6. **Red CI is read at once**: fetch the failing job's log (`gh api repos/aaronified/fluenough/actions/jobs/<id>/logs`), take the analyzer lines (`error •`, `warning •`, `info •`) or the failing test, and send them verbatim to the coder. Do not wait for a second notification.
7. **A rerun of failed jobs reuses the first run's artifacts and merge snapshot.** If the failure came from an earlier job's output (for example `validate-output`), rerun the whole run, or push a new commit.
8. **Every status report to the owner states the last verified fact and its time** (for example "CI on 16e3f9df: 12 failed at 20:06"), never a prediction. Do not describe an agent's or a watcher's result before its notification or output file has been read.
9. **On every wake-up and every new owner message, first list open pull requests and their check state** (one call), then answer.
10. A reviewer reading code cannot replace the compiler. No agent has a Dart SDK, so CI is the only compile: before asking for a review, the coder re-reads its diff for the traps in AGENTS.md "Compile traps".
