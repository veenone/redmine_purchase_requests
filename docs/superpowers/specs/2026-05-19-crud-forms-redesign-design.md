# CRUD Forms Redesign — Design Spec

**Date:** 2026-05-19
**Topic:** Unify and polish all CRUD forms in the redmine_purchase_requests plugin
**Status:** Approved (design)

## Goal

Make every create/edit form in the plugin look professional and visually
consistent by unifying them onto the existing `--pr-` design system, removing
rogue per-form styling, and polishing the shared form stylesheet.

## Problem

A capable design system already exists in
`assets/stylesheets/purchase_requests.css` (`:root` `--pr-` tokens,
`.pr-form-box`, `.form-section`, `.form-control`, focus rings, `.pr-button`
variants). It is applied **inconsistently**:

- **Vendors forms ship a parallel design.** `vendors/new.html.erb` and
  `project_vendors/new.html.erb` contain inline `<style>` blocks with hardcoded
  colors (`#007bff`, `#ddd`, `#333`), bespoke classes (`.vendor-form-section`,
  `.form-group`, `.form-help`, `.checkbox-group`, `.scope-badge`), and even
  redefine the global `.form-row` as a CSS grid — directly conflicting with the
  shared rules.
- **Duplicate page titles.** `opex/new`, `opex/edit`, and `tpc_codes/new`
  render a bare `<h2>` immediately above a `.pr-form-header` that contains its
  own title.
- **Required-marker drift.** Three patterns coexist: `<span class="required">*`,
  `<em class="required">*`, and `label class: 'required'` (which turns the whole
  label red). Statuses uses two markers at once.
- **Helper-text drift.** `<em class="info">` vs `<small class="form-help">`.
- **Field-row markup drift.** `<div class="form-row"><p>…</p></div>` vs
  `<div class="form-row">…</div>`.
- **Forms inlined in page templates.** `opex` and `tpc_codes` inline the whole
  form in `new.html.erb` (TPC's `edit` is `render template: 'tpc_codes/new'`);
  `opex/edit` duplicates the form body. Vendors has a `_form.html.erb` partial
  that `new`/`project_vendors#new` ignore in favor of inline copies.

## Approved Approach

Keep the existing `--pr-` design system. Migrate every CRUD form onto it,
delete all rogue inline CSS, polish the shared form styles, and consolidate
duplicated form bodies into single `_form` partials.

In scope: all 7 CRUD entities — Purchase Requests, CAPEX, OPEX, TPC Codes,
Vendors, Statuses, Workflow Templates (`new`, `edit`, and `_form` for each,
plus `project_vendors/new`).

## Visual Design

### Sectioned panel (replaces card-in-card)

Today `.form-section` is a grey (`--pr-surface-subtle`) bordered card nested
inside the white `.pr-form-box` — a busy "card in card". Target:

- `.pr-form-box` stays: white surface, hairline border, `--pr-radius`,
  `--pr-shadow-xs`.
- `.form-section` becomes a transparent delimited block: no fill, no border.
  Sections are separated by vertical spacing and a top hairline
  (`1px solid var(--pr-border)`), suppressed on the first section.
- `.form-section-title`: uppercase, letter-spaced, ~12px,
  `--pr-ink-muted`/strong weight, with a short bottom hairline.

All values come from existing `--pr-` tokens. No new colors are introduced.

### Standard page structure (every `new` / `edit`)

```
contextual            → back-link button (.pr-button)
.pr-form-container
  .pr-form-header     → .pr-form-title (h2) + .pr-form-subtitle (project/context)
  .pr-form-instructions  → .pr-alert.pr-alert-info  (on `new` only)
  .pr-form-box
    .pr-form-content  → <%= render 'form' %>
```

- The redundant bare `<h2>` above the container is removed (OPEX, TPC).
- `.pr-form-instructions` appears on `new` actions; omitted on `edit`.
- `html_title` and the `contextual` back-link are present on every page.
- The `_form` partial owns the fields and the `.pr-form-actions` footer.

### Standard field components

- **Field row** — `.form-row` directly contains `label`, the control, and an
  optional `<em class="info">` hint. The `<p>` wrapper is dropped everywhere.
- **Required marker** — exactly one rule: a plain `label` followed by
  `<span class="required">*</span>`. Labels never carry `class: 'required'`.
- **Helper text** — `<em class="info">` only; `<small class="form-help">` is
  retired.
- **Checkbox row** — a new shared `.pr-check` component: checkbox + inline
  label on one line, optional `<em class="info">` hint below. Replaces
  `.checkbox-group` and ad-hoc checkbox markup.
- **Two-up fields** — `.pr-field-pair` is kept; it collapses to a single
  column under the existing responsive breakpoint.
- **Form actions** — `.pr-form-actions`: right-aligned buttons on a recessed
  strip with a top hairline. Primary action `.pr-button-primary`, cancel
  `.pr-button-cancel`.

### Scope badge

The Vendors GLOBAL/PROJECT indicator is worth keeping. `.scope-badge`
(+ `.scope-badge.global` / `.scope-badge.project`) and its container move into
`purchase_requests.css`, re-expressed with `--pr-` tokens (`--pr-info`,
`--pr-warning`, `--pr-surface-subtle`).

## CSS Changes — `assets/stylesheets/purchase_requests.css`

Confined to the form area of the stylesheet:

1. Rework `.form-section` / `.form-section-title` to the transparent
   hairline-delimited treatment.
2. Polish `.form-control` (consistent control height for input/select/
   textarea), `.form-row`, `.pr-field-pair`, label, `.required`, `em.info`,
   `.pr-form-actions`.
3. Add `.pr-check` (checkbox row).
4. Add `.scope-badge` + scope-note container.
5. Keep all existing token definitions; reuse `.info-box` already defined in
   the shared stylesheet (the inline Vendors override is deleted).

No changes outside the form-related rules.

## ERB Changes

### Partial consolidation

- **OPEX** — extract `opex/_form.html.erb` from the body currently inlined in
  `new.html.erb`; `new` and `edit` both `render 'form'`. The quarterly-
  validation `<script>` moves into the `_form` partial so both actions get it.
- **TPC Codes** — extract `tpc_codes/_form.html.erb`; `new` renders it.
  `edit.html.erb` is rewritten as a standard `edit` wrapper that renders the
  partial directly, removing the current `render template: 'tpc_codes/new'`
  delegation hack.
- **Vendors** — one canonical `vendors/_form.html.erb` used by `vendors/new`,
  `vendors/edit`, and `project_vendors/new`. Inline `<style>` blocks and inline
  form copies are deleted.

### Per-entity normalization

Every `_form` and `new`/`edit` wrapper is brought to the standard structure and
field components above. Functional behavior — routes, form URLs/methods, field
names, validations, JS hooks (`capex_tpc_code_id`, `quarterly-input`,
`opex_tpc_code_id`, PR tabs/stepper) — is preserved exactly.

### Purchase Request form

The tabbed structure with the progress stepper is kept as-is structurally. It
receives only field-markup normalization (required marker, helper text,
field-row) and inherits the shared CSS polish. No teardown of tabs.

## File Inventory

CSS (1):
- `assets/stylesheets/purchase_requests.css`

ERB (~20):
- `purchase_requests/_form.html.erb`, `new.html.erb`, `edit.html.erb`
- `capex/_form.html.erb`, `new.html.erb`, `edit.html.erb`
- `opex/_form.html.erb` (new), `new.html.erb`, `edit.html.erb`
- `tpc_codes/_form.html.erb` (new), `new.html.erb`, `edit.html.erb`
- `vendors/_form.html.erb`, `new.html.erb`, `edit.html.erb`
- `project_vendors/new.html.erb`
- `purchase_request_statuses/_form.html.erb`, `new.html.erb`, `edit.html.erb`
- `purchase_request_workflow_templates/_form.html.erb`, `new.html.erb`, `edit.html.erb`

## Out of Scope

- List/index, dashboard, show, report, and settings views.
- Any controller, model, route, migration, or i18n change.
- New visual aesthetic or new color palette — tokens are reused as-is.
- Restructuring the Purchase Request tabbed flow.

## Success Criteria

- No inline `<style>` block remains in any form view; no hardcoded hex colors.
- Every CRUD `new`/`edit` page follows the standard page structure with a
  single page title.
- Required markers, helper text, and field rows use one markup pattern across
  all forms.
- OPEX, TPC, and Vendors render shared `_form` partials; no duplicated form
  bodies.
- All forms submit successfully and existing form JavaScript still works.
- `.form-section` renders as the flat sectioned-panel treatment.

## Risks

- **Shared CSS regressions.** `.form-row`, `.form-control`, `.form-section` are
  used by views outside this scope. Mitigation: changes stay backward-
  compatible with existing markup; affected non-form views are eyeballed after.
- **Behavior coupling in inlined forms.** OPEX/TPC/Vendors form JS targets
  specific element IDs. Mitigation: preserve IDs, names, and `<script>`
  behavior during extraction; verify each form's interactive logic.
