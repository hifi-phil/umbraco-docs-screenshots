# Slack mode — the channel-as-queue detail (Step 3, Slack branch)

Slack mode turns a channel into a request queue: anyone can drop an image link in as a message,
and each invocation of this skill works exactly one of them, replying in the message's own thread
with the result. This file is the precise algorithm and reply conventions — SKILL.md's Step 3 only
has the short version.

## Channel

`slack:#channel-name` resolves the channel via `slack_search_channels` (query on the name without
the `#`) to get its `channel_id`. **No default channel is configured yet** — until the team settles
on one, the channel must be given explicitly every invocation. Once it exists, update this line with
the actual channel and the SKILL.md note that says a default is pending.

## Reading the queue

Call `slack_read_channel` on the resolved `channel_id` with `response_format: 'detailed'`. It
returns messages **newest-first** as formatted text blocks, not JSON — reverse them before applying
the algorithm so you're working oldest→newest. Each block looks like this (verified against a real
channel):

```
=== Message from <Name> <email> (<user_id>) at <timestamp> ===
Message TS: 1785650402.531549
<message text>
Reactions: tada (28), de (23)
Thread: 2 replies (latest: 2026-08-03 06:33:03 BST)
```

The `Thread: N replies (...)` line is the tell that a message has replies at all — it's absent on
messages with none. `Message TS:` is the value to pass as `thread_ts` when replying, and as
`message_ts` to `slack_read_thread`.

**Candidate messages** are top-level channel messages whose text contains something that looks like
an image reference: a URL, or a path ending in `.png`/`.jpg`/`.jpeg`/`.gif`. Ignore anything else
(chatter, join notices, etc. — bot replies live in threads and don't show up in the channel-history
list at all, so they're never mistaken for a new candidate).

**Known limitation:** a single `slack_read_channel` call returns up to 100 messages. If the channel
ever accumulates more unprocessed history than that between runs, paginate with `cursor` — not
currently implemented, since the channel doesn't exist yet and volume is unknown.

## The "last-reply-then-next" algorithm

This is a **deliberate choice**, not the only reasonable option — an earlier draft of this feature
considered "process the oldest message with no reply at all," which is more defensive (never
permanently skips a message that failed to get a reply for some unrelated reason) but was rejected
in favor of a strict chronological queue. Implement it exactly as follows; don't substitute the
more defensive version:

1. Sort candidate messages ascending by timestamp (`Message TS:`).
2. For each, determine whether it already has a **completion reply** — a thread reply whose text
   starts with `✅ PR:` or `❌ Errored:` (see Reply format below). The `Thread: N replies (...)` line
   from `slack_read_channel` tells you whether a message has *any* replies at all; if so, call
   `slack_read_thread` (with that message's `Message TS:` as `message_ts`) to read the actual reply
   text and check it against those two prefixes specifically. **A reply that doesn't match either
   prefix does not count as completion** — a human asking a question in the thread, for instance,
   must not be mistaken for a processed marker.
3. Find the message with the **latest timestamp that has a confirmed completion reply**. Call its
   index in the sorted list `i`.
   - If no candidate message has a completion reply yet (a fresh queue), there is no `i` — the
     target is the **first** (oldest) candidate message.
   - Otherwise the target is the candidate at index `i + 1` — the next one posted **after** the
     last completed message, regardless of whether any earlier message (before `i`) also lacks a
     reply. Those earlier ones are not revisited by this algorithm.
4. If there is no message after index `i` (the last-completed message is also the newest candidate),
   there's nothing to do: end the run. No reply needed — nothing was chosen.

## Extracting and resolving the image reference

The message may have extra commentary around the link ("hey can someone update this? <url> thanks!")
— pull out just the URL or path token, preferring a URL if one is present, else falling back to a
bare path ending in an image extension (both forms verified against real message text):

```bash
TOKEN=$(echo "$RAW_TEXT" | grep -oE 'https?://[^ ]+' | head -1)
if [ -z "$TOKEN" ]; then
  TOKEN=$(echo "$RAW_TEXT" | grep -oE '[^[:space:]]+\.(png|jpg|jpeg|gif)' | head -1)
fi
```

Then normalize and resolve exactly like targeted mode:

```bash
REF="$(.claude/skills/update-docs-screenshots/scripts/normalize-image-ref.sh "$TOKEN")"
eval "$(.claude/skills/update-docs-screenshots/scripts/resolve-image.sh "$REF" "$DOCS")"
```

If `TOKEN` comes back empty (the message didn't actually contain a recognizable image reference),
treat that the same as a `resolve-image.sh` failure — reply `❌ Errored: no image link found in this
message` and move on; don't guess at what was meant.

`normalize-image-ref.sh` turns a pasted GitHub blob/raw URL into the plain docs-relative path
`resolve-image.sh` expects; a plain path passes through unchanged. **Known limitation:** it can't
resolve a GitHub blob URL whose branch/ref name itself contains a slash (e.g. `release/18.0`) — the
URL is genuinely ambiguous without querying GitHub's branch list, which this doesn't do. Very
unlikely for a pasted main-branch link; if it happens, `resolve-image.sh` will report "file not
found" and you can resolve it manually.

`slack_read_thread` (verified against a real threaded message) returns the parent message followed
by numbered replies, each with its own `From:`/`Time:`/`Message TS:`/text — scan each reply's text
for the two completion prefixes:

```
=== THREAD PARENT MESSAGE ===
From: ...
Message TS: 1785650402.531549
<parent text>

=== THREAD REPLIES (2 total) ===

--- Reply 1 of 2 ---
From: ...
Message TS: 1785652123.954509
<reply text>

--- Reply 2 of 2 ---
...
```

## Reply format — exact prefixes matter

The algorithm above parses reply text for these exact prefixes. Don't paraphrase them:

- **Success** (after `gh pr create` returns, per Step 9's note): reply in-thread
  (`thread_ts` = the target message's `ts`) with:
  ```
  ✅ PR: <pr-url>
  ```
- **Failure** at any point after the message was chosen — `resolve-image.sh` rejected it, the
  instance wouldn't start, the capture failed, anything else that ends the run early — reply
  in-thread with:
  ```
  ❌ Errored: <specific reason>
  ```
  Use the actual reason (the script's stderr message, or a short description of what went wrong) —
  it's what a human skimming the channel uses to decide whether to fix and re-drop the link, or
  investigate further.

Never post any other message shape as a way of marking a message handled — the queue algorithm
depends on these two prefixes to tell "done" from "just chatter."
