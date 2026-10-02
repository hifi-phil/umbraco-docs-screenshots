# Replace the asset and open the PR (Step 9 detail)

In the **docs repo**, on a feature branch, replace the asset (see the renaming check below), then
push and open the PR:

```bash
git -C "$DOCS" checkout main && git -C "$DOCS" pull --ff-only upstream main   # second sync — Step 1 already did one before Step 3's scan; this catches anything landed mid-run
git -C "$DOCS" checkout -b update-screenshot-<name>
```

**Always `git -C "$DOCS" …`, never `cd "$DOCS" && git …`.** Changing directory before a git
command raises a permission prompt every time, and an unattended routine has nobody to answer it
(see `gotchas.md`).

## Renaming check

**Check whether the filename itself should change first.** A stale version marker on the filename
(e.g. `cropping-images-v9.png`) is misleading once the shot shows the current UI — the version
*folder* (`17/`, `18/`) already disambiguates, so the marker on the filename is just leftover noise:

```bash
OLD_NAME="$(basename "<original-filename>")"
NEW_NAME="$(.claude/skills/update-docs-screenshots/scripts/rename-stale-image.sh "$OLD_NAME")"

ASSETS="$VERSION/umbraco-cms/.gitbook/assets"   # docs-relative asset dir of the image being replaced

if [ "$NEW_NAME" != "$OLD_NAME" ] && [ ! -e "$DOCS/$ASSETS/$NEW_NAME" ]; then
  cp "$HARNESS/screenshots/<name>.png" "$DOCS/$ASSETS/$NEW_NAME"
  git -C "$DOCS" rm --quiet "$ASSETS/$OLD_NAME"
  # Update markdown references in THIS version only — each major has its own copy of the asset, so
  # a repo-wide grep would also repoint 17/ articles at a file that only exists under 18/ (happened
  # in three real runs). Match `assets/<name>`, not the bare name: a bare `tree-v14.png` also matches
  # inside `prevaluesourcetree-v14.png` and `contenttree-v14.png`, and would rewrite those references
  # to files that don't exist. Portable (no GNU vs BSD sed difference):
  for f in $(grep -rlF "assets/$OLD_NAME" --include='*.md' "$DOCS/$VERSION"); do
    node -e "
      const fs = require('fs');
      const [file, oldName, newName] = process.argv.slice(1);
      fs.writeFileSync(file, fs.readFileSync(file, 'utf8').split('assets/' + oldName).join('assets/' + newName));
    " "$f" "$OLD_NAME" "$NEW_NAME"
  done
  git -C "$DOCS" diff --stat   # check: only the article(s) that really use this image should be listed
  git -C "$DOCS" add -A "$VERSION"   # picks up the renamed asset + every edited .md file
else
  cp "$HARNESS/screenshots/<name>.png" "$DOCS/$ASSETS/$OLD_NAME"
  git -C "$DOCS" add "$ASSETS/$OLD_NAME"
fi
```

The script only recognizes a version marker as a **suffix** (`-v9`, `_v9`, `v9` right before the
extension — the common case); a marker as a **prefix** (`v9-media-types...`) prints the name
unchanged, so it's left alone rather than guessed at. Also skips the rename if the new name would
collide with an existing file.

## Commit, push, open the PR

```bash
git -C "$DOCS" commit -m "Update <article> backoffice screenshot for v<version>"
git -C "$DOCS" push -u origin update-screenshot-<name>   # origin = the fork ($FORK_OWNER)
gh pr create --repo umbraco/UmbracoDocs --base main --head "$FORK_OWNER:update-screenshot-<name>" \
  --title "[AI] Update <article> backoffice screenshot" --body "Refreshed outdated pre-v14 screenshot for v<version>." \
  --label ai-screenshot
```

Every screenshot PR gets the **`ai-screenshot`** label (it already exists on `umbraco/UmbracoDocs`)
so reviewers can filter for them. If `gh pr create` fails on the label (e.g. no triage rights),
open the PR without it and say so in the run report rather than failing the run.

Everything above (`git checkout`/`add`/`commit`/`push`) works the same whether or not `gh` is
installed — only the final PR-creation call needs a fallback. See `references/github-fallback.md`
for the `mcp__github__*` path.

## Abandoning a candidate

If you decide not to ship this image after branching — a push rejected because the branch already
exists on the fork, an earlier closed PR for the same image, a capture that can't be made right —
clean up with the script, not hand-typed git:

```bash
.claude/skills/update-docs-screenshots/scripts/abandon-candidate.sh "$DOCS" update-screenshot-<name> [untracked-file ...]
```

It force-checks-out `main`, deletes the local branch (it only accepts `update-screenshot-*`
names), removes any untracked files you name by exact docs-relative path, and fails if the
checkout still isn't clean. A run that abandons a candidate this way hasn't opened a PR yet, so it
may go back to Step 3 for another candidate.

If the branch already exists on the fork, check for a PR with that head before doing anything
else. A closed one means a reviewer already turned the image down: abandon it, and suggest adding
it to `skip-images.txt` in the run report.

## Notes

- The branch lives on the fork (`origin`); the PR is opened against upstream `umbraco/UmbracoDocs`,
  base branch `main`. Open it **ready for review, not draft** (team preference), always prefix
  the title with **`[AI]`**, and add the **`ai-screenshot`** label, so reviewers can tell it was
  machine-generated at a glance.
- If the filename wasn't renamed, only an image changed and Vale has nothing to lint. **If it was
  renamed**, markdown files changed too — run `vale <changed.md>` on each and fix any errors before
  pushing.
- GitBook builds a preview per push; the PR checks include a `docs.umbraco.com` revision link — return
  it plus the PR URL to the user once it's built.
- **Any Slack-sourced run:** once `gh pr create` returns the PR URL, reply in-thread to the source
  message with `✅ PR: <pr-url>` right away — don't wait until Step 10. That reply is the durable
  record the next invocation's queue algorithm depends on.
