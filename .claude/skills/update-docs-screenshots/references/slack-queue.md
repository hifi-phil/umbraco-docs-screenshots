# Slack mode — the channel-as-queue detail (Step 3, Slack branch)

Slack mode turns a channel into a request queue: anyone can drop an image link in as a message,
and each invocation of this skill works exactly one of them, replying in the message's own thread
with the result. This file is the precise algorithm and reply conventions — SKILL.md's Step 3 only
has the short version.

## Channel

**Default: `#docs-screenshot-agent`** — a private channel, ID `C0BNAABAFK5` (resolved via
`slack_search_channels` and confirmed readable). A bare `slack` invocation uses this channel; only
pass `slack:#channel-name` to target a different one (resolve it the same way, by name, via
`slack_search_channels`).

**Live-tested against this channel** (2026-08-06): posted a real request message (a Slack-formatted
GitHub link with surrounding chatter), confirmed it's found as a candidate, confirmed the extraction
→ normalize → resolve chain resolves it correctly, then posted both an `❌ Errored:` and a
`✅ PR:` test reply in its thread and confirmed `Thread: N replies` and the read-back text both
behave exactly as documented below. Those test messages are still in the channel — clean them up
manually if you want it pristine before real use; they won't confuse the algorithm (the thread
already has a confirmed completion reply, so a real invocation would just move on to whatever's
posted after it).

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
currently implemented, since real usage volume is still unknown.

## The "last-reply-then-next" algorithm

This is a **deliberate choice**, not the only reasonable option — an earlier draft of this feature
considered "process the oldest message with no reply at all," which is more defensive (never
permanently skips a message that failed to get a reply for some unrelated reason) but was rejected
in favor of a strict chronological queue. Implement it exactly as follows; don't substitute the
more defensive version:

1. Sort candidate messages ascending by timestamp (`Message TS:`).
2. For each, determine whether it already has a **completion reply** — a thread reply whose text
   contains `PR:` or `Errored:` right after the leading emoji (see Reply format below — match on
   the **word**, not the emoji character). The `Thread: N replies (...)` line from
   `slack_read_channel` tells you whether a message has *any* replies at all; if so, call
   `slack_read_thread` (with that message's `Message TS:` as `message_ts`) to read the actual reply
   text and check it against those two markers specifically. **A reply that doesn't match either
   marker does not count as completion** — a human asking a question in the thread, for instance,
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

The message may have extra commentary around the link ("hey can someone update this? <url> thanks!"),
**and Slack itself wraps links as `<url|display-text>` or bare `<url>`** — confirmed live: a plain
`https://...` pasted into a message comes back from `slack_read_channel`/`slack_read_thread` wrapped
like `<https://github.com/.../foo.png|github.com/.../foo.png>`, not as a bare URL. Strip that first,
then fall back to a plain URL, then to a bare path ending in an image extension (all three forms
verified against real message text):

```bash
TOKEN=$(echo "$RAW_TEXT" | grep -oE '<https?://[^|>]+' | head -1 | sed 's/^<//')
if [ -z "$TOKEN" ]; then
  TOKEN=$(echo "$RAW_TEXT" | grep -oE 'https?://[^ >]+' | head -1)
fi
if [ -z "$TOKEN" ]; then
  TOKEN=$(echo "$RAW_TEXT" | grep -oE '[^[:space:]<>]+\.(png|jpg|jpeg|gif)' | head -1)
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
for the two completion markers (see Reply format below — by word, not emoji):

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

## Reply format — match on the words, never the emoji

**Verified live (posted real test replies and read them back):** `slack_send_message` accepts a
literal `✅`/`❌`, but `slack_read_channel`/`slack_read_thread` return it back as Slack's own
shortcode — `✅` → `:white_check_mark:`, `❌` → `:x:`. **The algorithm must match on the word that
follows (`PR:` / `Errored:`), never on the emoji character** — matching the emoji itself would
silently never find a completion reply, since what comes back isn't what was sent.

Post these exact shapes (the emoji is for human readability in Slack; keep it, just don't depend on
it for parsing):

- **Success** (after `gh pr create` returns, per Step 9's note): reply in-thread
  (`thread_ts` = the target message's `Message TS:`) with:
  ```
  ✅ PR: <pr-url>
  ```
  — which reads back as `:white_check_mark: PR: <pr-url>`. Match candidate replies against `PR:`.
- **Failure** at any point after the message was chosen — `resolve-image.sh` rejected it, the
  instance wouldn't start, the capture failed, anything else that ends the run early — reply
  in-thread with:
  ```
  ❌ Errored: <specific reason>
  ```
  — which reads back as `:x: Errored: <specific reason>`. Match candidate replies against `Errored:`.
  Use the actual reason (the script's stderr message, or a short description of what went wrong) —
  it's what a human skimming the channel uses to decide whether to fix and re-drop the link, or
  investigate further.

Never post any other message shape as a way of marking a message handled — the queue algorithm
depends on these two markers to tell "done" from "just chatter."
