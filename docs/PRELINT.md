# Prelint in this project

This repository is reviewed by [Prelint](https://prelint.com), which checks pull requests against
the decisions the project has written down rather than against code style. This document records
what it is configured to do, how the loop works, and what it actually caught.

## Why it is here

The submission's decisions live in [`DECISIONS.md`](DECISIONS.md), [`ARCHITECTURE.md`](ARCHITECTURE.md)
and [`AI_INTEGRATION.md`](AI_INTEGRATION.md). A conventional review reads the diff; it cannot tell
whether the diff still agrees with those documents. Prelint reads them and reviews each pull
request against them, which is the failure mode this project is most exposed to, because most of
what it claims is *behavioural*: no privileged identity, no secret in the repository, no
unlabelled degradation, nothing claimed that the code does not contain.

That risk is not theoretical here. Building under time pressure produced exactly that class of
defect twice:

- the README advertised a second mode (Compose) that `grep -ri compose app/ core/` could not find;
- the decision ledger said "92 tests" while two checklists still said "84".

The first was caught by a manual audit. The second was caught by Prelint, in its first review.

## Configuration

[`../prelint.json`](../prelint.json) is the repository-level configuration, which has the highest
priority of any Prelint scope and is versioned with the code, so a change to it is reviewed like
any other change.

- **`rules`** encode the seven constraints that matter most, in the imperative form the review
  engine expects: no privileged identity, no secret in the repository, the engine stays
  platform-agnostic, degradation is labelled and nothing throws, documentation is backed by the
  code, observed behaviour is separated from expectation, and the system is not modified.
  Each rule names the concrete thing that would violate it, rather than restating a principle.
- **`context_files`** add the decision ledger and the architecture notes as background, so the
  review understands the intent behind a diff instead of judging it in isolation.
- **`trigger_mode: "auto"`**, with the exclusions kept to the built-in bots.
- **Docs are deliberately not ignored.** The decisions and specs of this project *are* markdown,
  so excluding documentation would exclude the very thing the review is supposed to enforce.

## The loop

```
branch  ->  commit  ->  push  ->  open PR  ->  Prelint reviews  ->  read findings
                                                       |
                              fix the drift  <---------+
                                       |
                              push  ->  re-review  ->  findings resolved
```

Two operational details worth knowing, both learned the hard way:

- **Prelint reviews pull requests, not commits.** Work committed straight to `main` is invisible
  to it. The organisers' agent guidance says to branch for new work anyway; this makes that
  guidance load-bearing rather than stylistic.
- **`@prelint` starts a review on demand**, which is the reliable way to get one on a PR that
  predates the repository being connected, or on a draft.

## What it caught

On pull request [#1](https://github.com/rafalohaki/harmonyy/pull/1), the first review returned
one finding:

> **Warning.** D8 states "92 tests" ran before any SDK existed, but `docs/SETUP.md` line 305 and
> `README.md` line 134 both still assert "84 tests pass" as the expected verification result.

That is correct, and it was verified independently before being acted on: the suite really does
report 92, and both files really did still say 84. It is also precisely the class of defect that
no linter, type checker or test can see — the code and the tests were both fine, and the *claims
about* them had gone stale. Two files were corrected and the correction was pushed to the same
pull request, so the finding is resolved in the next review rather than argued away.

A review finding is treated as a report to check, not an instruction to obey: the first step is
always to reproduce it in the repository.
