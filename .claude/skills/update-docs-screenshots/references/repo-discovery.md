# Repo discovery (Step 1 detail)

Resolution script for `$HARNESS`, `$DOCS`, and `$FORK_OWNER`. **Do not hardcode paths** — run this
verbatim rather than guessing at locations, so the skill stays machine-agnostic.

```bash
# Capture harness = the repo that contains this skill (normally your working directory).
HARNESS="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Docs repo: look as a sibling first, then a couple of common roots. A real checkout has a
# .gitbook.yaml at its root and version folders like 17/ and 18/.
DOCS=""
for c in \
  "$(dirname "$HARNESS")"/UmbracoDocs "$(dirname "$HARNESS")"/umbraco-docs \
  "$(dirname "$HARNESS")"/docs "$HOME"/Projects/UmbracoDocs "$HOME"/UmbracoDocs; do
  if [ -f "$c/.gitbook.yaml" ] && [ -d "$c/18" ]; then DOCS="$c"; break; fi
done
# Bounded fallback search if still not found.
if [ -z "$DOCS" ]; then
  DOCS="$(find "$HOME" -maxdepth 5 -name .gitbook.yaml 2>/dev/null \
          | while read -r f; do d="$(dirname "$f")"; \
              git -C "$d" remote -v 2>/dev/null | grep -qi 'UmbracoDocs' && echo "$d" && break; done)"
fi

echo "HARNESS = $HARNESS"
echo "DOCS    = ${DOCS:-NOT FOUND}"
```

If `$DOCS` is empty, **ask the user for the absolute path to their UmbracoDocs checkout** and use
that. Do not guess or proceed without it.

Derive the fork owner (head namespace for the PR) from the docs repo's `origin` remote — never
assume a username:

```bash
FORK_OWNER="$(gh repo view "$DOCS" --json owner -q .owner.login 2>/dev/null \
  || git -C "$DOCS" remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$#\1#')"
echo "FORK_OWNER = $FORK_OWNER"
```
