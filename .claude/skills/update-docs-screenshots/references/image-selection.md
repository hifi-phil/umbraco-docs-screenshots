# Choosing the image — default mode's discovery-fallback phase (Step 3 detail)

Targeted mode has no judgment call to document here — `scripts/resolve-image.sh` resolves and
validates the supplied path deterministically (see SKILL.md Step 3).

The discovery-fallback phase does need judgment — reading images and deciding whether they're
outdated isn't scriptable — but **don't scan the whole tree**: `$DOCS/<version>/umbraco-cms/**` and `$DOCS/<version>/umbraco-forms/**` holds around 3,800 images combined across both majors, and reading anywhere near that many isn't feasible or necessary for a job that only needs to find **one** candidate per run.

1. Get a bounded, prioritized shortlist instead of enumerating the whole tree yourself:

   ```bash
   .claude/skills/update-docs-screenshots/scripts/list-stale-candidates.sh "$VERSION" "$DOCS" 20 "$FORK_OWNER"
   ```

   It leaves out images a reviewer has already turned down: everything in `skip-images.txt`, plus
   every image touched by one of `$FORK_OWNER`'s closed-unmerged screenshot PRs
   (`scripts/list-rejected-images.sh`, ~10s of REST calls). Without that, a rejected
   old-version-marked image sits at the top of the list forever — `sensitive-data-user-group-v8.png`
   was re-captured and abandoned in four consecutive routine runs.

   **If it prints `WARN: couldn't list rejected-PR images`, don't carry on with that shortlist** —
   it can contain already-rejected images (a cloud run re-picked `cropping-images-v9.png` this way
   and lost the whole capture to the existing branch). Rebuild the rejected list by hand per
   `references/github-fallback.md` and drop those basenames from the shortlist before reading any
   images.

   It prioritizes images whose filename carries an **old** version marker (`v1`–`v13` — the
   highest-hit-rate signal for staleness found by testing against the real repo), falls back to
   the large unmarked bulk pool in random order (so repeated runs sample different parts of it
   instead of always hitting the same files), and excludes images already marked with the
   **current** version (`v17`/`v18` as appropriate) since those are almost always already
   refreshed. Both tiers are shuffled, so repeated runs see different candidates. Capped to 20
   paths by default — pass a third argument to change that.

   Git commit dates were tried first and rejected as a prioritization signal: a file's last-commit
   date often reflects an unrelated bulk restructuring or GitBook-sync commit, not a real content
   update (verified — a genuinely stale `v10`-suffixed file's last real content commit was in
   2023, despite an unrelated 2026 docs-infra commit making it look recently touched).

2. Read the articles that reference these shortlisted images (not every article in the tree) and
   look at the screenshots directly to judge them. Images live in flat `.gitbook/assets/` folders
   (or legacy `images/` folders) beside the content.
3. **Detect the outdated ones by the pre-v14 AngularJS signature:**
   - Circular Umbraco logo, top-left.
   - Horizontal coloured section tabs across the top (Content / Media / Settings / … as tabs).
   - Old grey tree styling and old workspace chrome.
   Any of these means the shot predates the Bellissima redesign and is outdated for v17/v18.
   (The current UI has a dark left rail of section icons, a light tree panel, and Lit web-component
   workspaces.)
4. **Surface a single best candidate** — the image plus the article that uses it. Confirm it is
   locally reproducible (a CMS or Forms backoffice screen — not a Cloud/Deploy dialog and not
   any other add-on product), then take it forward autonomously (SKILL.md's autonomy note
   applies here). Skip the Forms landing/dashboard page specifically — it shows a trial banner
   on this demo instance that a real licensed install wouldn't have.
5. Choose **one** candidate for this run and take only that one forward. This run ends when its PR is
   open (Step 10) — any other candidates are left for a future invocation.
6. **One PR per run is not one attempt per run.** If a candidate dies before a PR is open — it isn't
   stale, isn't reproducible locally, its `update-screenshot-*` branch already exists, or the capture
   can't match — abandon it (`scripts/abandon-candidate.sh` if a branch was made) and move to the
   next shortlist entry. Keep going until a PR is open or you have **tried 5 candidates**
   (re-run the script for a fresh shortlist if it runs out — both tiers reshuffle). Rejecting a
   candidate just by looking at it is cheap and doesn't count toward the 5; only candidates you
   started navigating/capturing do.
7. **Record every dead end with a PR on the harness repo.** Runs can't commit to this repo's
   checkout, so before ending — whether or not this run opened a docs PR — pass each candidate you
   rejected for a lasting reason to:

   ```bash
   .claude/skills/update-docs-screenshots/scripts/propose-skip-entries.sh "$HARNESS" \
     "Typeahead-v8.png|v18 Tags editor shows no suggestion dropdown" \
     "User_Type_v13.png|Google Cloud console screen, not the backoffice"
   ```

   It opens one `[AI] Skip discovery dead ends` PR adding those lines to `skip-images.txt`, using a
   throwaway worktree outside the repo (your checkout stays clean), and drops anything already
   skipped or pending in another open skip PR. Open skip PRs take effect immediately —
   `list-stale-candidates.sh` excludes their entries until a reviewer merges or closes them.
   Exit `3`/`4` means the branch was pushed but the PR call failed: open it with
   `mcp__github__create_pull_request` (head = the branch on stderr, base `main`, same title).

   **Only lasting verdicts belong here** — not a screen, not reproducible on a vanilla CMS, a
   deliberately old shot, already current UI. A transient failure (timeout, selector you couldn't
   find, instance trouble) is not a dead end; leave it for a future run. Include the PR URL in the
   run summary and push notification.
