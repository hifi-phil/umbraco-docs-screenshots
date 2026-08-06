# Mode invocation and scheduling detail (Three modes section)

## Invocation syntax

Targeted mode is for local, interactive use — you already know which image is stale, so the scan is
wasted work and the reviewer-load guard shouldn't block you. Invoke it with a path relative to the
docs repo root, or an absolute one:

```
/update-docs-screenshots 18/umbraco-cms/fundamentals/data/defining-content/images/query-builder.png
/update-docs-screenshots /Users/me/Projects/UmbracoDocs/18/umbraco-cms/.../query-builder.png
```

Slack mode is for a shared request queue — anyone can drop an image link in the channel, and each
invocation works exactly one of them, replying in-thread with the result:

```
/update-docs-screenshots slack                          # defaults to #docs-screenshot-agent
/update-docs-screenshots slack:#some-other-channel
```

The default channel and its ID are in `references/slack-queue.md` — only pass `slack:#channel-name`
to target a different one.

## What differs, what doesn't

Targeted and Slack mode relax **candidate selection only** — everything else is unchanged, including
the one-PR-per-run rule (see the top of SKILL.md). Steps 4–10 are identical across all three modes,
except that Slack mode has one extra obligation layered on top: **whatever step ends the run —
success or failure — reply in the source message's thread before stopping** (Step 3's Slack branch
and `references/slack-queue.md` spell out the exact reply format; don't let a failed run leave the
thread silent, or the next invocation has no way to know that message was already attempted).

## Scheduling

Discovery and Slack mode are both designed to run **as a scheduled/repeated routine**. To avoid
overwhelming the docs PR reviewers, successive runs must not stack up open PRs — Step 2 bails out
early if a screenshot PR from a previous run is still open. Pacing differs by mode: scheduled
discovery/Slack runs refresh the next screenshot only after the previous PR is merged/closed (the
Step 2 hard stop); targeted runs aren't paced at all — you chose to open that one.
