# Choosing the image (Step 3 detail)

Follow **one** of the two sections below, matching the mode from SKILL.md, never both.

## Targeted

Resolve the argument against the docs repo first, then as a path in its own right, so both
docs-relative and absolute forms work:

```bash
ARG="<the path the user supplied>"
IMG=""
if   [ -f "$DOCS/$ARG" ]; then IMG="$DOCS/$ARG"
elif [ -f "$ARG" ];       then IMG="$(cd "$(dirname "$ARG")" && pwd)/$(basename "$ARG")"
fi

REL="${IMG#$DOCS/}"           # e.g. 18/umbraco-cms/.../foo.png
VERSION="${REL%%/*}"          # 17 | 18
echo "IMG=${IMG:-NOT FOUND}  REL=$REL  VERSION=$VERSION"
```

Then validate. Each failure **ends the run** with the specific reason — never fall back to the
discovery branch and never silently substitute a different image:

- **`IMG` empty (file missing)** → say the path was not found and ask for the correct one.
- **Not inside `$DOCS`** (`REL` still starts with `/`) → the image must live in the docs checkout
  resolved in Step 1.
- **`VERSION` is neither `17` nor `18`** → only those have demo instances here, so a `13/…` or
  `16/…` path cannot be recaptured.
- **Not under `<version>/umbraco-cms/`** → out of scope per the Scope section in SKILL.md (cloud,
  Deploy dialogs, add-on products). Explain it is not locally reproducible.

On success, `$VERSION` picks the instance in Step 4 and `$IMG` is the target asset for Steps 5–9.

**The pre-v14 AngularJS check is not a gate here.** The user picked this image, so recapturing one
that already shows the current UI is legitimate. Read the PNG, note in one line what it looks like
(outdated / already current), and carry on.

## Discovery

Work through `$DOCS/<version>/umbraco-cms/**` only.

1. Read the articles (`.md` / `README.md`) and look at the backoffice screenshots they reference.
   Images live in flat `.gitbook/assets/` folders (or legacy `images/` folders) beside the content.
   Read the PNGs directly to judge them.
2. **Detect the outdated ones by the pre-v14 AngularJS signature:**
   - Circular Umbraco logo, top-left.
   - Horizontal coloured section tabs across the top (Content / Media / Settings / … as tabs).
   - A `Forms` section tab.
   - Old grey tree styling and old workspace chrome.
   Any of these means the shot predates the Bellissima redesign and is outdated for v17/v18.
   (The current UI has a dark left rail of section icons, a light tree panel, and Lit web-component
   workspaces.)
3. **Surface a single best candidate** — the image plus the article that uses it — and confirm with
   the user before capturing. Confirm it is locally reproducible (a CMS backoffice screen, not a
   Cloud/Deploy dialog and not an add-on product).
4. Choose **one** candidate for this run and take only that one forward. This run ends when its PR is
   open (Step 10) — any other candidates are left for a future invocation.
