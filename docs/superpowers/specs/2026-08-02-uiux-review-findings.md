# UI/UX Review — Findings & Prioritized Recommendations

**Date:** 2026-08-02
**Plugin:** Redmine Purchase Requests (v1.8.1)
**Method:** Read-only audit by two specialists (visual design + UX/interaction/accessibility) over the `pr-` design system (`assets/stylesheets/purchase_requests.css`, ~1839 lines) and a representative sample of list, detail, dashboard, form, settings, and report views.
**Detailed source reports:** `.superpowers/sdd/ui-findings.md` (visual) · `.superpowers/sdd/ux-findings.md` (UX/a11y).

Each item is tagged **Severity** (High/Med/Low) × **Effort** (S/M/L).

---

## Executive summary

The core design system is genuinely mature and modern — a token-driven ("`--pr-*`") slate + indigo system with surfaces, borders, ink, semantic colors, radii, a 3-step shadow scale, and focus rings. **The system is not the problem.** Almost every finding is one of three things:

1. **Views that bypass the system** — ~503 inline `style=` attributes and 23 embedded `<style>` blocks, concentrated in the **reports** and **settings** pages, plus a **second, clashing Chart.js color palette** (dated Material `#4CAF50/#2196F3/#FF9800`) that makes charts look like a different product than the cards around them.
2. **The four dashboard filter bars diverge** — the recently-added year + TPC filters behave four different ways across CAPEX / OPEX / PR / TPC (missing labels, inconsistent "Clear," muted `.no-data` used as an active-filter indicator, TPC facet never acknowledged), and **auto-submit-on-change is a keyboard trap** with no loading state and scroll loss.
3. **One missing token family** — the system tokenizes color/radius/shadow but **not a type or spacing scale**, which is why the outlier views fall back to magic px values.

**The highest-ROI work is not a redesign — it's (a) making reports/settings consume the existing system, (b) unifying the chart palette, (c) adding the type+space tokens, and (d) consolidating the four filter bars into one shared, accessible partial.**

---

## Tier A — Quick wins directly tied to the new TPC/filter work (do first)

These are low-effort, high-visibility, and directly clean up what the filter/TPC-name work just touched.

| # | Change | Sev × Effort | Evidence |
|---|--------|--------------|----------|
| A1 | **Consolidate the 4 dashboard filter bars into one shared `_dashboard_filters` partial** — one legend word, one "Clear" rule (appears when *any* facet active), one indicator style, one `onchange` string. Fixes the TPC-only "no Clear" gap and the CAPEX "no labels" gap in one move. | High × S–M | 3.1 / 6.2 (ux) |
| A2 | **Make the active-filter indicator a real chip, not `.no-data`** — replace the muted grey "Showing data for 2026" span with `.pr-badge--accent` chips that show *every* active facet (`Year: 2026 · TPC: TPC-2025-001`) and are removable. Today the TPC filter gets zero acknowledgement. | Med × S | 3.2 / 6.3 (ux); `purchase_requests/dashboard.html.erb:54-57`, `tpc_codes/dashboard.html.erb:47-49` |
| A3 | **Add `<label for>`/`id` to the CAPEX/OPEX selects** (PR & TPC already do this correctly) so all four dashboards have associated labels. | High × S | 4.1 (ux); `capex/dashboard.html.erb:34-40` |
| A4 | **Make auto-submit keyboard-safe** — `onchange:this.form.submit()` reloads on the first arrow key, trapping keyboard users. Add an explicit **Apply** button, or submit on `blur`/Enter. (Bundles with A1.) | High × S–M | 2.1 / 4.2 / 6.1 (ux) |
| A5 | **Give filter `<select>`s the same `:focus` ring as `.form-control`** — currently they get none, so they feel cheaper than form inputs. | Low × S | 4.4 (ui); `purchase_requests.css:850-864, 940` |
| A6 | **Remove the inert `include_blank: false` on the `select_tag` filters** and normalize the `onchange` string (drop the trailing-semicolon inconsistency). Dead-code cleanup from the filter tasks. | Low × S | our SDD ledger; 3.1 (ux) |
| A7 | **Truncate long TPC `display_name` in the filter dropdown** (+`title`) and plan a searchable combobox once option count > ~15. | Low–Med × M | 6.4 (ux) |

## Tier B — Design-system consistency (high impact across the whole plugin)

| # | Change | Sev × Effort | Evidence |
|---|--------|--------------|----------|
| B1 | **Unify the Chart.js palette to token colors** — one `PR_CHART_COLORS` JS constant mirroring `--pr-*`, applied across all 7 report charts (which currently hardcode a clashing Material palette) and the native SVG charts. Single most jarring "different product" fix. | High × M | 2.1 (ui); `reports/*.html.erb` chart configs |
| B2 | **Add the missing `--pr-text-*` and `--pr-space-*` token scale to `:root`** (~20 lines, non-breaking). Prerequisite for de-sprawling; collapses 15/17/19/22/28px one-offs and the 18-vs-22 gap drift. | High × S | 1.2 / 3.1 / 6.1 (ui) |
| B3 | **Add `overflow-x:auto` to `.autoscroll` + a `.pr-table` min-width** — 10-column PR and TPC-report tables overflow `#content` on tablets/phones today, clipping the Actions column. | High × S | 5.1 (ux); `purchase_requests.css:1819` |
| B4 | **Promote repeated report inline patterns to classes** (`.pr-rank-row`, `.pr-usage-card`, `.pr-report-card`, `.pr-stack--cards`) and reuse `.pr-stat`/`.pr-card`/`.pr-badge`. Removes the bulk of the 503 inline styles; gives reports the polish of the tables. | High × M–L | 3.2 / 4.1 / 5.1 (ui); `reports/tpc_codes.html.erb:84-256` |
| B5 | **De-duplicate the 8 identical settings `<style>` blocks** into one stylesheet section; fix the em/px unit drift. | Med × S | 5.3 / 1.3 (ui) |
| B6 | **Delete dead `*_backup` / `*_clean` / `*_old` view variants** — removes ~7 files, several legacy `<style>` blocks, and the worst off-token colors (`#007bff`, `#f5f5f5`) in one commit. | Med × S | 5.4 (ui) |
| B7 | **Tokenize the `#777777` status fallback + move it to a model helper** (`status.display_color`) so ~10 views stop repeating the literal. | Med × S | 2.3 (ui) |
| B8 | **Centralize the currency-symbol map** (copy-pasted in 3+ views/JS) into one helper to stop cross-screen rendering drift. | Low–Med × M | 3.4 (ux) |
| B9 | **Table polish using existing tokens** — hover elevation on linked cards, wire the already-emitted `.odd/.even` zebra classes, sticky `thead` inside `.autoscroll`. | Med × S | 6.3 / 6.4 (ui) |

## Tier C — Deeper UX & accessibility (higher effort, real payoff)

| # | Change | Sev × Effort | Evidence |
|---|--------|--------------|----------|
| C1 | **Right-size the dashboards** — 12 equal-weight cards + chart-then-duplicate-table bury the answer. Pin the 4 KPI tiles, add a 2-card primary-insight row, collapse the long tail; make duplicate tables a "View data" `<details>`. | Med × M | 1.1 / 1.3 (ux) |
| C2 | **Surface price + budget link on the show page** header/first tab — the two most-asked facts are currently behind a `display:none` "Details" tab. | Med × M | 1.2 (ux) |
| C3 | **Replace `alert()` validation with inline field errors** — `.pr-field__error` already exists; add `aria-invalid`/`aria-describedby`, focus the field. | Med × M | 2.3 (ux); `_form.html.erb:1023-1060` |
| C4 | **Proper ARIA tabs** on show/form (roles, arrow-key nav, `location.hash` sync so reloads/deep-links keep the tab). | Med × M | 4.6 (ux) |
| C5 | **Status legibility & non-color cue** — compute readable fg from background luminance (drops the white-on-pale text-shadow crutch); add a non-color signal for closed/over-budget. | Med × M | 4.3 / 4.4 (ux), 4.2 (ui) |
| C6 | **Table semantics** — `scope="col"`, `<thead>`, visually-hidden `<caption>`; collapse row actions to icon-only on narrow screens; add `rel="noopener"` to `target=_blank`. | Med × S–M | 4.5 / 5.2 / 4.7 (ux) |
| C7 | **Responsive depth** — an intermediate breakpoint, lower card `minmax` floor, and a debounced `resize` handler so the JS/SVG charts re-render on rotate. | Med × M | 5.3 / 5.4 (ux) |
| C8 | **Dark-mode readiness** — one additive `@media (prefers-color-scheme: dark)` block redefining the ~30 tokens (everything already routes through them). Deferrable. | Low × M | 2.5 (ui) |

---

## Recommended implementation order

1. **Tier A (A1–A6)** — one focused pass on the filter bar + a11y + focus ring. Directly finishes the filter/TPC work cleanly. *(~½–1 day)*
2. **B2 + B3 + B1** — add tokens, fix table overflow, unify chart palette. Biggest visible consistency gains for low effort. *(~1 day)*
3. **B6 + B5 + B7 + B4** — delete dead views, de-dupe settings CSS, tokenize status color, then the larger report class-promotion. *(~1–2 days)*
4. **B8, B9** — currency helper + table polish.
5. **Tier C** — schedule as follow-ups; C1/C2 give the most user-facing value, C3–C7 are accessibility/robustness.

## Notes

- This report is the deliverable of Task 8 (report-first). No view/CSS changes have been made for it.
- Items A1–A6 are the natural finish to the TPC filter feature and are the recommended next commit if you want to proceed.
- Full per-finding detail (with before→after values) is in the two source reports referenced at the top.
