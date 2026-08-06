# Choosing the image — discovery mode (Step 3 detail)

Targeted mode has no judgment call to document here — `scripts/resolve-image.sh` resolves and
validates the supplied path deterministically (see SKILL.md Step 3).

Discovery mode does need judgment — reading images and deciding whether they're outdated isn't
scriptable — but **don't scan the whole tree**: `$DOCS/<version>/umbraco-cms/**` holds around 3,800
images combined across both majors, and reading anywhere near that many isn't feasible or
necessary for a job that only needs to find **one** candidate per run.

1. Get a bounded, prioritized shortlist instead of enumerating the whole tree yourself:

   ```bash
   .claude/skills/update-docs-screenshots/scripts/list-stale-candidates.sh "$VERSION" "$DOCS"
   ```

   It prioritizes images whose filename carries an **old** version marker (`v1`–`v13` — the
   highest-hit-rate signal for staleness found by testing against the real repo), falls back to
   the large unmarked bulk pool in random order (so repeated runs sample different parts of it
   instead of always hitting the same files), and excludes images already marked with the
   **current** version (`v17`/`v18` as appropriate) since those are almost always already
   refreshed. Capped to 20 paths by default — pass a third argument to change that.

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
   - A `Forms` section tab.
   - Old grey tree styling and old workspace chrome.
   Any of these means the shot predates the Bellissima redesign and is outdated for v17/v18.
   (The current UI has a dark left rail of section icons, a light tree panel, and Lit web-component
   workspaces.)
4. **Surface a single best candidate** — the image plus the article that uses it. Confirm it is
   locally reproducible (a CMS backoffice screen, not a Cloud/Deploy dialog and not an add-on
   product), then take it forward autonomously — **don't pause for a human to confirm it**; this
   mode runs unattended, and the draft PR is the actual review checkpoint.
5. Choose **one** candidate for this run and take only that one forward. This run ends when its PR is
   open (Step 10) — any other candidates are left for a future invocation. If none of the shortlist
   turned out to be a good candidate, re-run the script for a fresh shortlist (the random portion
   reshuffles) rather than falling back to an unbounded scan.
