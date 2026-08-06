# Scope — what's out of bounds (Repos/instances section detail)

The local demo instances are a vanilla CMS, so only CMS backoffice screens are reproducible.
**Skip everything else — do not treat these as candidates**, in any mode:

- **Cloud:** `umbraco-cloud/`, `umbraco-heartcore/`, `umbraco-compose/`, and Deploy-only dialogs
  (Compare / Queue for transfer / Transfer now / Partial restore — these need a Current-vs-Live
  Cloud environment and cannot be reproduced locally).
- **Add-on products:** `umbraco-commerce/`, `umbraco-deploy/`, `umbraco-engage/`,
  `umbraco-ui-builder/`, `umbraco-workflow/`, and the other non-CMS areas (`umbraco-forms/`,
  `umbraco-search/`, `umbraco-automate/`, `ai-*`).

Effective candidate scope: **`$DOCS/<version>/umbraco-cms/**` only** (version = `17` or `18`).

This applies identically across all three modes: discovery's scan never enters these directories,
a targeted/Slack path pointing into one of them is rejected by `resolve-image.sh` (out of the
`umbraco-cms` scope), and a Slack request for one should get `❌ Errored: <area>` isn't reproducible
locally — not silently captured against the wrong thing.
