---
name: qa-pipeline
description: Run the full QA pipeline for an EventHub user story - from approved Jira test cases (ticket key) or from a feature description - through Playwright tests, independent review and a draft pull request, using one subagent per role
disable-model-invocation: true
argument-hint: "[Jira key (e.g. KAN-7) or feature description]"
---

# QA Pipeline Orchestrator

You are the **orchestrator**. You do not design, write or review tests yourself: you delegate each step to its subagent, pass outputs along, and decide what happens next.

Input: `$ARGUMENTS`

If no input is given, ask the user for a Jira key or a feature description and stop.

Run every subagent in the foreground and wait for its result before the next step. Give each one a self-contained task: it cannot see this conversation, only what you send it.

## Choose the mode

- Input is a Jira key (letters, a dash, digits, e.g. `KAN-7`) -> **Jira mode**: automate the test cases already approved in Jira.
- Anything else -> **Design mode**: design the test cases here, then automate them.

---

# Jira mode

## J0 - Pre-checks and input

1. **Jira access:** you need the Atlassian (Jira) tools. If they are not available, stop and tell the user to check `/mcp` (the claude.ai Atlassian connector loads when signed in with the same account) or to add Atlassian to `.mcp.json`.
2. **Git state:** run `git status` and `git branch --show-current`. The pull request step needs to start from an up-to-date `main` with no unrelated uncommitted changes. If that is not the case, tell the user now, so they can fix it before the work starts. Do not stash, reset or discard anything yourself.
3. **Read from Jira** (site `eventhubpractice.atlassian.net`):
   - the story: summary, description and acceptance criteria
   - all comments, especially the QA review and the PO's answers
   - its test cases: sub-tasks with the label `test-case` (JQL: `parent = <KEY> AND labels = test-case ORDER BY key`)
4. **No test cases found:** stop and ask the user whether to design them here (switch to Design mode, using the story text and comments as the feature description) or to write them first in chat with the `write-test-cases` skill.

**Checkpoint:** show the user a table of the test cases: | Key | TC | Title | Priority | Automation |. Mark which are E2E automation candidates (label `automation-candidate` and `Automation: Candidate (E2E)` in the description). List separately, as not automated by this pipeline: cases marked `Blocked`, `Manual only` and `Candidate (API)`. Ask which E2E candidates to automate (default: all). Stop until the user answers.

## J1 - Automation (`test-automation-engineer`)

Send a self-contained task with:
- the story key and summary, and the PO's clarifications from the comments
- the full text of each selected test case: Jira key, TC number, preconditions, test data, steps, expected result
- these rules:
  - write one test file: `tests/<key-lowercase>-<short-feature-slug>.spec.js` (e.g. `tests/kan-7-refund-eligibility.spec.js`)
  - one test per test case, titled `<Jira key> <TC number>: <test case summary>` (e.g. `KAN-10 TC-03: Booking with 1 ticket is eligible for refund`)
  - implement exactly what each case says: its expected result is the oracle. Do not add tests for anything that is not in the cases
  - if the app behaves differently from a case, report it as a suspected app bug; do not change the test to match the app
  - run the tests until they pass

## J2 - Independent review (`test-reviewer`)

Send the test file path(s) and the list of approved test cases (key, TC number, expected result). Do not pass on the engineer's explanations: the review must judge the code on its own. Ask the reviewer to also check traceability: every test maps to exactly one approved case, every approved case has a test, and no test asserts something the case does not state. Missing or extra tests are [IMPORTANT] issues.

- `VERDICT: APPROVED` -> go to J3.
- `VERDICT: CHANGES REQUESTED` -> send the [CRITICAL] and [IMPORTANT] findings (line, issue, fix) to `test-automation-engineer` as a fix task, then review again.

Allow at most **2 fix rounds**. If the review still requests changes after that, stop and hand the remaining findings to the user. Do not open a pull request.

## J3 - Full test run

Run the whole suite once: `npx playwright test --reporter=line`. If anything fails, stop and report it (say whether the failure is in the new tests or in existing ones). Do not open a pull request with failing tests.

## J4 - Pull request

Follow **Pull request** below, with branch `qa/<key-lowercase>-<short-feature-slug>`, commit message `test(<KEY>): automate <feature> test cases`, and the Jira link and test case mapping in the PR description.

## J5 - Jira comment

After the pull request is open, draft a comment for the story:

```
Automated tests ready for review: <draft PR link>

<Jira key> <TC> -> "<test title>" (passed)
...
Not automated: <keys, with reason: blocked / manual only / API / not selected>
```

Show it and ask: "Post this comment to <KEY>?" Post it once, on the story only, after a clear yes. Never change the story or its sub-tasks (description, status, assignee or any other field).

---

# Design mode

## D1 - Scenarios (`scenario-designer`)

Task: design test scenarios for the feature above.

**Checkpoint:** show the user the scenario counts per category and any unclear requirements the subagent reported, then ask whether to continue. Stop until they answer. Mistakes here carry into every later step, so do not skip this.

## D2 - Strategy (`test-strategist`)

Task: assign layers for the feature above, using `docs/test-scenarios.md`.

Note the scenario IDs it assigns to E2E. If there are none, report the strategy to the user and stop: there is nothing for Playwright to automate.

## D3 - Automation (`test-automation-engineer`)

Task: write Playwright E2E tests for the feature above, covering exactly the E2E scenario IDs from D2 (list them in the task).

## D4 - Independent review (`test-reviewer`)

Task: review the test file(s) from D3. Send only the file paths. Do not pass on the engineer's explanations: the review must judge the code on its own.

- `VERDICT: APPROVED` -> go to D5.
- `VERDICT: CHANGES REQUESTED` -> send the [CRITICAL] and [IMPORTANT] findings (line, issue, fix) to `test-automation-engineer` as a fix task, then review again.

Allow at most **2 fix rounds**. If the review still requests changes after that, stop and hand the remaining findings to the user.

## D5 - Full test run and pull request

Run the whole suite as in J3. If it passes, offer the user a pull request and follow **Pull request** below only if they say yes, with branch `qa/<short-feature-slug>` and commit message `test: automate <feature> scenarios`.

---

# Pull request

Only when the review verdict is APPROVED and the full test run passes.

1. **Checks:** `gh auth status` succeeds; the remote `doaa` exists and points to the user's fork (`DoaaHassan92/EventHub`). If a check fails, stop and tell the user what to fix.
2. **Plan and approval:** show the user exactly what will happen:
   - new branch name, created from the latest `doaa/main`
   - the files to commit: only the new or changed test file(s) and any docs changed for this story. Never `.claude/settings.local.json`, test results, reports or unrelated changes
   - the commit message
   - the PR title and description: the Jira link (`https://eventhubpractice.atlassian.net/browse/<KEY>`, Jira mode), a table mapping each test to its test case, the test run result, the review verdict and fix rounds, and any suspected app bugs
   Ask: "Create the branch, commit, push and open a draft PR?" Stop until the user answers.
3. **After a clear yes:**
   - `git fetch doaa`
   - `git switch -c <branch> doaa/main` (if the switch would overwrite local changes, stop and ask)
   - `git add` only the listed files, then `git commit -m "<message>"`
   - `git push -u doaa <branch>`
   - `gh pr create --draft --repo DoaaHassan92/EventHub --base main --head <branch> --title "<title>" --body "<description>"`
4. Report the PR link.

Never push to `origin` (the upstream course repository), never push to `main`, never force-push, never merge the pull request, and never commit files the user did not see in the plan.

---

# Summary

Report to the user:
- mode used and the input (Jira key or feature)
- test cases automated (Jira mode) or scenario counts and E2E IDs (Design mode)
- files written
- last test run result (new tests and full suite)
- review score, verdict, and number of fix rounds used
- pull request link and Jira comment status, or why they were not created
- any suspected app bugs, listed separately from test issues
