# Mode invocation and scheduling detail (Three modes section)

## Invocation syntax

Targeted mode is for local, interactive use — you already know which image is stale, so the scan is
wasted work and the reviewer-load guard shouldn't block you. Invoke it with a path relative to the
docs repo root, or an absolute one:

```
/update-docs-screenshots 18/umbraco-cms/fundamentals/data/defining-content/images/query-builder.png
/update-docs-screenshots /Users/me/Projects/UmbracoDocs/18/umbraco-cms/.../query-builder.png
```

Default mode is a bare invocation — no argument — and is how scheduled/repeated runs fire. It is
**two phases run in strict order, never both in the same invocation:**

```
/update-docs-screenshots
```

1. **Slack-check phase:** read `#docs-screenshot-agent` (the default channel) as a queue — anyone
   can drop an image link in there, and this phase works the next unhandled one, replying in-thread
   with the result. See `references/slack-queue.md` for the exact algorithm.
2. **Discovery-fallback phase:** only reached if phase 1 found nothing new (empty queue, or every
   candidate message already has a completion reply). Falls back to scanning the docs repo for a
   stale-screenshot candidate and picking one itself.

Explicit Slack mode targets one **specific, non-default** channel's queue only, with no
discovery-fallback phase — use it when you want to work a different channel than the default one:

```
/update-docs-screenshots slack:#some-other-channel
```

(A bare `slack` invocation is unnecessary now that default mode's phase 1 already checks the default
channel — there is no behavioral difference between them other than explicit Slack mode's lack of a
discovery fallback.)

## What differs, what doesn't

Targeted mode and both Slack-sourced paths (default mode's phase 1, and explicit Slack mode) relax
**candidate selection only** — everything else is unchanged, including the one-PR-per-run rule (see
the top of SKILL.md). Steps 4–10 are identical regardless of how the image was chosen, except that
any Slack-sourced run has one extra obligation layered on top: **whatever step ends the run —
success or failure — reply in the source message's thread before stopping** (Step 3's Slack-check
phase and `references/slack-queue.md` spell out the exact reply format; don't let a failed run leave
the thread silent, or the next invocation has no way to know that message was already attempted).

## Scheduling

Default mode and explicit Slack mode are both designed to run **as a scheduled/repeated routine**.
To avoid overwhelming the docs PR reviewers, successive runs must not stack up open PRs without
bound — Step 2 bails out once **8 or more** screenshot PRs from previous runs are still open (not at
1 — a handful of open PRs awaiting review is the normal, expected steady state for this routine).
Pacing differs by mode: scheduled default/explicit-Slack runs stop opening new PRs once the 8-PR
ceiling is hit, resuming once reviewers merge/close some of them back down (the Step 2 hard stop);
targeted runs aren't paced at all — you chose to open that one.
