# Choosing the image — discovery mode (Step 3 detail)

Targeted mode has no judgment call to document here — `scripts/resolve-image.sh` resolves and
validates the supplied path deterministically (see SKILL.md Step 3).

Discovery mode does need judgment: it's reading images and deciding whether they're outdated, which
isn't scriptable. Work through `$DOCS/<version>/umbraco-cms/**` only.

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
