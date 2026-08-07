# Replace the asset and open the PR (Step 9 detail)

In the **docs repo**, on a feature branch, replace the asset (see the renaming check below), then
push and open a draft PR:

```bash
cd "$DOCS"
git checkout main && git pull upstream main
git checkout -b update-screenshot-<name>
```

## Renaming check

**Check whether the filename itself should change first.** A stale version marker on the filename
(e.g. `cropping-images-v9.png`) is misleading once the shot shows the current UI — the version
*folder* (`17/`, `18/`) already disambiguates, so the marker on the filename is just leftover noise:

```bash
OLD_NAME="$(basename "<original-filename>")"
NEW_NAME="$(.claude/skills/update-docs-screenshots/scripts/rename-stale-image.sh "$OLD_NAME")"

if [ "$NEW_NAME" != "$OLD_NAME" ] && [ ! -e "<asset-dir>/$NEW_NAME" ]; then
  cp "$HARNESS/screenshots/<name>.png" "<asset-dir>/$NEW_NAME"
  git rm --quiet "<asset-dir>/$OLD_NAME"
  # Update every markdown reference to the old filename — portable (works without GNU vs BSD sed):
  for f in $(grep -rl "$OLD_NAME" --include='*.md' .); do
    node -e "
      const fs = require('fs');
      const [file, oldName, newName] = process.argv.slice(1);
      fs.writeFileSync(file, fs.readFileSync(file, 'utf8').split(oldName).join(newName));
    " "$f" "$OLD_NAME" "$NEW_NAME"
  done
  git add -A   # picks up the renamed asset + every edited .md file
else
  cp "$HARNESS/screenshots/<name>.png" "<asset-dir>/$OLD_NAME"
  git add "<asset-dir>/$OLD_NAME"
fi
```

The script only recognizes a version marker as a **suffix** (`-v9`, `_v9`, `v9` right before the
extension — the common case); a marker as a **prefix** (`v9-media-types...`) prints the name
unchanged, so it's left alone rather than guessed at. Also skips the rename if the new name would
collide with an existing file.

## Commit, push, open the PR

```bash
git commit -m "Update <article> backoffice screenshot for v<version>"
git push origin update-screenshot-<name>          # origin = the fork ($FORK_OWNER)
gh pr create --repo umbraco/UmbracoDocs --base main --head "$FORK_OWNER:update-screenshot-<name>" --draft \
  --title "Update <article> backoffice screenshot" --body "Refreshed outdated pre-v14 screenshot for v<version>."
```

Everything above (`git checkout`/`add`/`commit`/`push`) works the same whether or not `gh` is
installed — only the final PR-creation call needs a fallback. See `references/github-fallback.md`
for the `mcp__github__*` path.

## Notes

- The branch lives on the fork (`origin`); the PR is opened against upstream `umbraco/UmbracoDocs`,
  base branch `main`. Keep it a **draft** unless the user says otherwise.
- If the filename wasn't renamed, only an image changed and Vale has nothing to lint. **If it was
  renamed**, markdown files changed too — run `vale <changed.md>` on each and fix any errors before
  pushing.
- GitBook builds a preview per push; the PR checks include a `docs.umbraco.com` revision link — return
  it plus the PR URL to the user once it's built.
- **Any Slack-sourced run** (default mode's Slack-check phase, or explicit Slack mode): once
  `gh pr create` returns the PR URL, reply in-thread to the source message with `✅ PR: <pr-url>`
  right away — don't wait until Step 10. That reply is the durable record the next invocation's
  queue algorithm depends on.
