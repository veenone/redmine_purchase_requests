# CRUD Forms Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify every create/edit form in the redmine_purchase_requests plugin onto the existing `--pr-` design system so they look professional and consistent.

**Architecture:** One CSS foundation task reworks the shared form styles in `assets/stylesheets/purchase_requests.css`. Then one task per entity rewrites its `_form` partial + `new`/`edit` wrappers to a single standard structure. OPEX and TPC get new `_form` partials extracted from inlined markup; Vendors collapses three divergent copies into one partial and loses its inline `<style>`.

**Tech Stack:** Redmine 6 / Rails 6.1 ERB views, plain CSS with `--pr-` custom properties, jQuery (Redmine core).

**Spec:** `docs/superpowers/specs/2026-05-19-crud-forms-redesign-design.md`

---

## Conventions

Every form view in this plan follows these canonical patterns. They are referenced by name in each task; do not deviate.

### CANON-A — `_form` partial skeleton

The `_form` partial owns the `form_for`/`form_with`, the error block, the sections, and the actions footer. The `new`/`edit` wrapper never contains form logic — it only calls `render 'form'`.

```erb
<%= form_with model: <model-or-array>, url: <url>, method: <method>, local: true, html: { class: '<entity>-form' } do |f| %>
  <%# CANON-E error block %>

  <%# CANON-C sections %>

  <div class="pr-form-actions">
    <%= f.submit <submit-label>, class: 'pr-button pr-button-primary' %>
    <%= link_to <cancel-label>, <cancel-path>, class: 'pr-button pr-button-cancel' %>
  </div>
<% end %>
```

### CANON-B — `new` wrapper

```erb
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
  <%= javascript_include_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title "New <Entity>" %>

<div class="contextual">
  <%= link_to <index-path>, class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel">Back to <Entity> List</span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2>New <Entity></h2>
      <div class="pr-form-subtitle">
        <span class="icon icon-info"></span>
        <%= <context-string> %>
      </div>
    </div>
  </div>

  <div class="pr-form-instructions">
    <div class="pr-alert pr-alert-info">
      <span class="icon icon-info"></span>
      <div class="pr-alert-content">
        <h4><Short heading></h4>
        <p><One sentence of guidance.></p>
      </div>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= render 'form' %>
    </div>
  </div>
</div>
```

The `edit` wrapper is identical EXCEPT: `html_title "Edit <Entity>"`, the `<h2>` reads `Edit <Entity>`, and the entire `<div class="pr-form-instructions">…</div>` block is omitted.

Rules:
- Exactly ONE page title — the `<h2>` inside `.pr-form-title`. Never a bare `<h2>` above `.pr-form-container`.
- A form that has no extra JS only needs the `stylesheet_link_tag` line; keep `javascript_include_tag` lines that the form already required.

### CANON-C — section

```erb
<div class="form-section">
  <div class="form-section-title"><Section Name></div>
  <%# field rows %>
</div>
```

### CANON-D — field rows

Single field:
```erb
<div class="form-row">
  <%= f.label :attr, '<Label>' %> <span class="required">*</span>
  <%= f.text_field :attr, class: 'form-control' %>
  <em class="info"><Helper text.></em>
</div>
```
- Omit `<span class="required">*</span>` when the field is optional.
- Omit the `<em class="info">` line when there is no hint.
- The label NEVER carries `class: 'required'`.
- No `<p>` wrapper inside `.form-row`.

Two fields side by side:
```erb
<div class="pr-field-pair">
  <div class="form-row"><%# field A %></div>
  <div class="form-row"><%# field B %></div>
</div>
```

Checkbox field:
```erb
<div class="form-row">
  <div class="pr-check">
    <%= f.check_box :attr %>
    <%= f.label :attr, '<Label>' %>
    <em class="info"><Helper text.></em>
  </div>
</div>
```
- Omit the `<em class="info">` line when there is no hint.

### CANON-E — error block

```erb
<% if <model>.errors.any? %>
  <div class="pr-alert pr-alert-danger">
    <span class="icon icon-warning"></span>
    <div class="pr-alert-content">
      <h4><%= pluralize(<model>.errors.count, 'error') %> prohibited this <entity> from being saved:</h4>
      <ul>
        <% <model>.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  </div>
<% end %>
```

### Verification method

There is no unit-test layer for views. Each task is verified by:
1. **Restart:** `touch tmp/restart.txt` from the plugin's Redmine root.
2. **Render check:** open the entity's `new` and `edit` pages in a browser; confirm HTTP 200 and no `ActionView::Template::Error`.
3. **Visual check:** the page shows one title, sections as flat hairline-delimited blocks, inputs/buttons styled by the `--pr-` system, no off-brand colors.
4. **Behavior check:** submit the form; any form-specific JS still works (noted per task).

---

## Task 1: Shared CSS foundation

**Files:**
- Modify: `assets/stylesheets/purchase_requests.css`

- [ ] **Step 1: Rework `.form-section` / `.form-section-title`**

Replace the existing block (currently `#content .form-section, #content .pr-section { … }` through the `.form-section-title` rule, around lines 962-981) with:

```css
/* Grouped form section — flat, hairline-delimited */
#content .form-section,
#content .pr-section {
  margin: 24px 0 0;
  padding: 24px 0 0;
  border-top: 1px solid var(--pr-border);
}
#content .form-section:first-child,
#content .pr-section:first-child {
  margin-top: 0;
  padding-top: 0;
  border-top: none;
}
#content .form-section-title,
#content .pr-section__title {
  margin: 0 0 16px;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--pr-border);
  color: var(--pr-ink-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: .06em;
  text-transform: uppercase;
}
```

- [ ] **Step 2: Polish `.form-control` padding**

In the `#content .form-control, …` rule (around line 905-923), change `padding: 7px 11px;` to `padding: 8px 12px;`. Leave every other declaration unchanged.

- [ ] **Step 3: Add `.pr-check` and `.scope-badge` components**

Immediately AFTER the `.form-section-title` rule from Step 1, add:

```css
/* Checkbox row */
#content .pr-check {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
#content .pr-check input[type="checkbox"] { margin: 0; }
#content .pr-check label {
  margin: 0;
  color: var(--pr-ink);
  font-size: 13px;
  font-weight: 600;
}
#content .pr-check em.info,
#content .pr-check .info {
  flex-basis: 100%;
  margin-top: 2px;
}

/* Scope note + badge */
#content .pr-scope-note {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 20px;
  padding: 12px 14px;
  background: var(--pr-surface-subtle);
  border: 1px solid var(--pr-border);
  border-radius: var(--pr-radius-sm);
  color: var(--pr-ink-muted);
  font-size: 13px;
}
#content .scope-badge {
  display: inline-block;
  padding: 3px 9px;
  border-radius: var(--pr-radius-pill);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: .04em;
  text-transform: uppercase;
}
#content .scope-badge.global  { background: var(--pr-info-soft);    color: var(--pr-info-ink); }
#content .scope-badge.project { background: var(--pr-warning-soft); color: var(--pr-warning-ink); }
```

- [ ] **Step 4: Verify**

Run: `grep -n "pr-check\|scope-badge\|form-section" assets/stylesheets/purchase_requests.css`
Expected: the new rules appear once each; no duplicate `.form-section` block remains.

Run: `touch tmp/restart.txt` and load any existing form page (e.g. CAPEX new). Expected: HTTP 200; sections now render without the grey nested-card fill.

- [ ] **Step 5: Commit**

```bash
git add assets/stylesheets/purchase_requests.css
git commit -m "style: rework shared form CSS — flat sections, pr-check, scope-badge"
```

---

## Task 2: Statuses form

Smallest form — validates the canonical pattern end to end.

**Files:**
- Modify: `app/views/purchase_request_statuses/_form.html.erb`
- Modify: `app/views/purchase_request_statuses/new.html.erb`
- Modify: `app/views/purchase_request_statuses/edit.html.erb`

- [ ] **Step 1: Rewrite `_form.html.erb`**

The partial now owns the `form_for` and the actions footer (currently in the wrappers). It receives no locals — it references `@status` directly. Full new content:

```erb
<%= form_with model: @status, url: (@status.new_record? ? purchase_request_statuses_path : purchase_request_status_path(@status)), method: (@status.new_record? ? :post : :patch), local: true, html: { class: 'status-form' } do |f| %>
  <% if @status.errors.any? %>
    <div class="pr-alert pr-alert-danger">
      <span class="icon icon-warning"></span>
      <div class="pr-alert-content">
        <h4><%= pluralize(@status.errors.count, 'error') %> prohibited this status from being saved:</h4>
        <ul>
          <% @status.errors.full_messages.each do |message| %>
            <li><%= message %></li>
          <% end %>
        </ul>
      </div>
    </div>
  <% end %>

  <div class="form-section">
    <div class="form-section-title"><%= l(:label_status_name) %></div>

    <div class="form-row">
      <%= f.label :name, l(:label_status_name) %> <span class="required">*</span>
      <%= f.text_field :name, required: true, class: 'form-control' %>
    </div>

    <div class="form-row">
      <%= f.label :position, l(:label_position) %>
      <%= f.number_field :position, min: 1, value: @status.position || 1, class: 'form-control' %>
    </div>
  </div>

  <div class="form-section">
    <div class="form-section-title"><%= l(:label_status_color) %></div>

    <div class="form-row">
      <%= f.label :color, l(:label_color) %>
      <%= f.color_field :color, value: @status.color || '#777777', class: 'form-control' %>
      <em class="info">Choose a color to visually identify this status in lists and badges.</em>
    </div>
  </div>

  <div class="form-section">
    <div class="form-section-title">Behavior</div>

    <div class="form-row">
      <div class="pr-check">
        <%= f.check_box :is_closed %>
        <%= f.label :is_closed, l(:label_status_is_closed) %>
        <em class="info">Closed statuses indicate a request has reached a terminal state.</em>
      </div>
    </div>

    <div class="form-row">
      <div class="pr-check">
        <%= f.check_box :is_default %>
        <%= f.label :is_default, l(:label_is_default) %>
        <em class="info"><%= l(:text_is_default_info) %></em>
      </div>
    </div>
  </div>

  <div class="pr-form-actions">
    <%= f.submit (@status.new_record? ? l(:button_create) : l(:button_update)), class: 'pr-button pr-button-primary' %>
    <%= link_to l(:button_cancel), purchase_request_statuses_path, class: 'pr-button pr-button-cancel' %>
  </div>
<% end %>
```

Note: `error_messages_for` is replaced by the CANON-E block. The `color_field` keeps the `form-control` class.

- [ ] **Step 2: Rewrite `new.html.erb`**

Per CANON-B. Statuses are an admin/global list (no project context, no extra JS):

```erb
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title l(:label_new_status) %>

<div class="contextual">
  <%= link_to purchase_request_statuses_path, class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel"><%= l(:label_purchase_request_statuses, default: 'Back to Statuses') %></span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2><%= l(:label_new_status) %></h2>
    </div>
  </div>

  <div class="pr-form-instructions">
    <div class="pr-alert pr-alert-info">
      <span class="icon icon-info"></span>
      <div class="pr-alert-content">
        <h4><%= l(:label_new_status) %></h4>
        <p>Define a workflow status with a name, list position, color, and terminal behavior.</p>
      </div>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= render 'form' %>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Rewrite `edit.html.erb`**

Same as Step 2 but: `html_title l(:label_edit_status)`, `<h2>` reads `<%= l(:label_edit_status) %>`, and the whole `<div class="pr-form-instructions">…</div>` block is removed.

```erb
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title l(:label_edit_status) %>

<div class="contextual">
  <%= link_to purchase_request_statuses_path, class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel"><%= l(:label_purchase_request_statuses, default: 'Back to Statuses') %></span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2><%= l(:label_edit_status) %></h2>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= render 'form' %>
    </div>
  </div>
</div>
```

- [ ] **Step 4: Verify**

`touch tmp/restart.txt`. Open the statuses list, click "New", then edit an existing status. Expected on both: HTTP 200, single title, three flat sections, the two checkboxes render as `.pr-check` rows, name field shows a single red `*`. Submit a new status — it saves and redirects.

- [ ] **Step 5: Commit**

```bash
git add app/views/purchase_request_statuses/_form.html.erb app/views/purchase_request_statuses/new.html.erb app/views/purchase_request_statuses/edit.html.erb
git commit -m "style: unify purchase request status form onto pr- design system"
```

---

## Task 3: Workflow Templates form

`_form.html.erb` already contains `form_with` + `.pr-form-actions` (CANON-A shape). It needs field-markup normalization only. Wrappers already match CANON-B closely.

**Files:**
- Modify: `app/views/purchase_request_workflow_templates/_form.html.erb`
- Modify: `app/views/purchase_request_workflow_templates/new.html.erb`
- Modify: `app/views/purchase_request_workflow_templates/edit.html.erb`

- [ ] **Step 1: Rewrite `_form.html.erb`**

Normalize per CANON-D: remove `<p>` wrappers, remove `class: 'required'` from the name label, convert the two checkboxes to `.pr-check`. Full new content:

```erb
<%= form_with model: @template, local: true do |f| %>
  <% if @template.errors.any? %>
    <div class="pr-alert pr-alert-danger">
      <span class="icon icon-warning"></span>
      <div class="pr-alert-content">
        <h4><%= pluralize(@template.errors.count, 'error') %> prohibited this template from being saved:</h4>
        <ul>
          <% @template.errors.full_messages.each do |message| %>
            <li><%= message %></li>
          <% end %>
        </ul>
      </div>
    </div>
  <% end %>

  <div class="form-section">
    <div class="form-section-title">Template Details</div>

    <div class="form-row">
      <%= f.label :name, l(:field_name, default: 'Name') %> <span class="required">*</span>
      <%= f.text_field :name, required: true, class: 'form-control' %>
    </div>

    <div class="form-row">
      <%= f.label :description, l(:field_description, default: 'Description') %>
      <%= f.text_area :description, rows: 3, class: 'form-control' %>
    </div>

    <div class="form-row">
      <%= f.label :position, l(:field_position, default: 'Position') %>
      <%= f.number_field :position, min: 1, step: 1, class: 'form-control' %>
    </div>
  </div>

  <div class="form-section">
    <div class="form-section-title">Assignment &amp; Tracking</div>

    <div class="form-row">
      <%= f.label :tracker_id, l(:field_tracker, default: 'Tracker') %>
      <%= f.collection_select :tracker_id, Tracker.sorted, :id, :name,
          { include_blank: l(:label_use_default_tracker, default: '-- Use default tracker --') },
          { class: 'form-control' } %>
      <em class="info"><%= l(:hint_template_tracker, default: 'Tracker to use for this subtask (optional)') %></em>
    </div>

    <div class="form-row">
      <%= f.label :default_assigned_to_id, l(:field_assigned_to, default: 'Default Assignee') %>
      <%= f.collection_select :default_assigned_to_id, User.active.sorted, :id, :name,
          { include_blank: l(:label_no_default_assignee, default: '-- No default assignee --') },
          { class: 'form-control' } %>
    </div>

    <div class="form-row">
      <%= f.label :estimated_hours, l(:field_estimated_hours, default: 'Estimated Hours') %>
      <%= f.number_field :estimated_hours, min: 0, step: 0.5, class: 'form-control' %>
    </div>
  </div>

  <div class="form-section">
    <div class="form-section-title">Behavior</div>

    <div class="form-row">
      <div class="pr-check">
        <%= f.check_box :is_active %>
        <%= f.label :is_active, l(:field_active, default: 'Active') %>
      </div>
    </div>

    <div class="form-row">
      <div class="pr-check">
        <%= f.check_box :auto_create %>
        <%= f.label :auto_create, l(:label_auto_create, default: 'Auto Create') %>
        <em class="info"><%= l(:hint_auto_create, default: 'Automatically create this subtask when a workflow issue is created') %></em>
      </div>
    </div>
  </div>

  <div class="pr-form-actions">
    <%= f.submit l(:button_save, default: 'Save'), class: 'pr-button pr-button-primary' %>
    <%= link_to l(:button_cancel, default: 'Cancel'),
        plugin_settings_path('redmine_purchase_requests', tab: 'workflow'),
        class: 'pr-button pr-button-cancel' %>
  </div>
<% end %>
```

- [ ] **Step 2: Update `new.html.erb`**

The current wrapper uses `<h2 class="pr-form-title">` directly. Replace the `.pr-form-header` block so the title is wrapped in `.pr-form-title` per CANON-B, and add the contextual back-link + instructions. Full new content:

```erb
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title l(:label_new_workflow_template, default: 'New Workflow Template') %>

<div class="contextual">
  <%= link_to plugin_settings_path('redmine_purchase_requests', tab: 'workflow'), class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel"><%= l(:label_workflow_templates, default: 'Back to Workflow') %></span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2><%= l(:label_new_workflow_template, default: 'New Workflow Template') %></h2>
    </div>
  </div>

  <div class="pr-form-instructions">
    <div class="pr-alert pr-alert-info">
      <span class="icon icon-info"></span>
      <div class="pr-alert-content">
        <h4><%= l(:label_new_workflow_template, default: 'New Workflow Template') %></h4>
        <p>Define a subtask template that can be auto-created for workflow issues.</p>
      </div>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= render 'form' %>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Update `edit.html.erb`**

Full new content (no instructions block; title note shows the template name in the subtitle):

```erb
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title l(:label_edit_workflow_template, default: 'Edit Workflow Template') %>

<div class="contextual">
  <%= link_to plugin_settings_path('redmine_purchase_requests', tab: 'workflow'), class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel"><%= l(:label_workflow_templates, default: 'Back to Workflow') %></span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2><%= l(:label_edit_workflow_template, default: 'Edit Workflow Template') %></h2>
      <div class="pr-form-subtitle">
        <span class="icon icon-edit"></span>
        <%= @template.name %>
      </div>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= render 'form' %>
    </div>
  </div>
</div>
```

- [ ] **Step 4: Verify**

`touch tmp/restart.txt`. From plugin settings → Workflow tab, open "New Template" and edit an existing one. Expected: HTTP 200, single title, three flat sections, both checkboxes as `.pr-check`. Submit — it saves and returns to the workflow settings tab.

- [ ] **Step 5: Commit**

```bash
git add app/views/purchase_request_workflow_templates/_form.html.erb app/views/purchase_request_workflow_templates/new.html.erb app/views/purchase_request_workflow_templates/edit.html.erb
git commit -m "style: unify workflow template form onto pr- design system"
```

---

## Task 4: CAPEX form

`_form.html.erb` already holds `form_for` + `.pr-form-actions` and uses `form-section`/`pr-field-pair`. It needs `<p>`-wrapper removal and a checkbox-free normalization. Wrappers already match CANON-B.

**Files:**
- Modify: `app/views/capex/_form.html.erb`
- Modify: `app/views/capex/new.html.erb`
- Modify: `app/views/capex/edit.html.erb`

- [ ] **Step 1: Rewrite `_form.html.erb`**

Keep the `form_for`, the currency option list, the quarterly grid, and the entire `<script>` block at the bottom EXACTLY as they are. Only the markup between changes: drop `<p>` wrappers, keep `<span class="required">*</span>` markers. Full new content for the form body (everything from `<%= form_for … %>` through `<% end %>`, followed by the unchanged `<script>`):

```erb
<%# filepath: app/views/capex/_form.html.erb %>
<% form_url = @capex.new_record? ? project_capex_index_path(@project) : project_capex_path(@project, @capex) %>
<% form_method = @capex.new_record? ? :post : :patch %>

<%= form_for [@project, @capex], url: form_url, method: form_method, html: { class: 'capex-form' } do |f| %>
  <% if @capex.errors.any? %>
    <div class="pr-alert pr-alert-danger">
      <span class="icon icon-warning"></span>
      <div class="pr-alert-content">
        <h4><%= pluralize(@capex.errors.count, 'error') %> prohibited this CAPEX entry from being saved:</h4>
        <ul>
          <% @capex.errors.full_messages.each do |message| %>
            <li><%= message %></li>
          <% end %>
        </ul>
      </div>
    </div>
  <% end %>

  <div class="form-section">
    <div class="form-section-title">Basic Information</div>

    <div class="pr-field-pair">
      <div class="form-row">
        <%= f.label :year, 'CAPEX Year' %> <span class="required">*</span>
        <%= f.number_field :year, required: true, min: 2000, max: 2100,
                            value: @capex.year || Date.current.year, class: 'form-control' %>
      </div>
      <div class="form-row">
        <%= f.label :description, 'Description' %> <span class="required">*</span>
        <%= f.text_field :description, required: true, class: 'form-control' %>
      </div>
    </div>

    <div class="pr-field-pair">
      <div class="form-row">
        <%= f.label :total_amount, 'Total Amount' %> <span class="required">*</span>
        <%= f.number_field :total_amount, required: true, step: 0.01, min: 0, class: 'form-control' %>
      </div>
      <div class="form-row">
        <%= f.label :currency, 'Currency' %> <span class="required">*</span>
        <%= f.select :currency,
                     options_for_select([
                       ['USD - US Dollar', 'USD'], ['EUR - Euro', 'EUR'], ['GBP - British Pound', 'GBP'],
                       ['JPY - Japanese Yen', 'JPY'], ['CAD - Canadian Dollar', 'CAD'], ['AUD - Australian Dollar', 'AUD'],
                       ['CHF - Swiss Franc', 'CHF'], ['CNY - Chinese Yuan', 'CNY'], ['SEK - Swedish Krona', 'SEK'],
                       ['NZD - New Zealand Dollar', 'NZD'], ['MXN - Mexican Peso', 'MXN'], ['SGD - Singapore Dollar', 'SGD'],
                       ['HKD - Hong Kong Dollar', 'HKD'], ['IDR - Indonesian Rupiah', 'IDR'], ['NOK - Norwegian Krone', 'NOK'],
                       ['KRW - South Korean Won', 'KRW'], ['TRY - Turkish Lira', 'TRY'], ['RUB - Russian Ruble', 'RUB'],
                       ['INR - Indian Rupee', 'INR'], ['BRL - Brazilian Real', 'BRL'], ['ZAR - South African Rand', 'ZAR']
                     ], @capex.currency), { required: true }, { class: 'form-control' } %>
      </div>
    </div>
  </div>

  <div class="form-section">
    <div class="form-section-title">TPC Code</div>

    <div class="pr-field-pair">
      <div class="form-row">
        <%= f.label :tpc_code_id, 'TPC Code' %>
        <%= f.collection_select :tpc_code_id,
                               TpcCode.available_for_project(@project).active.ordered,
                               :id, :display_name,
                               { prompt: 'Select TPC Code (optional)' },
                               { class: 'form-control', id: 'capex_tpc_code_id' } %>
        <em class="info">Link this CAPEX entry to a TPC code for tracking</em>
      </div>
      <div class="form-row tpc-code-field">
        <%= f.label :tpc_code, 'Legacy TPC Code' %>
        <%= f.text_field :tpc_code, maxlength: 50, id: 'capex_tpc_code', class: 'form-control' %>
        <em class="info">Unique identifier (only required if no TPC code is selected above)</em>
      </div>
    </div>
  </div>

  <div class="form-section">
    <div class="form-section-title">Quarterly Distribution</div>

    <div class="pr-alert pr-alert-info">
      <span class="icon icon-info"></span>
      <div class="pr-alert-content">
        <p>Distribute the total amount across quarters. The sum of all quarters must equal the total amount.</p>
      </div>
    </div>

    <div class="capex-quarterly-grid">
      <div class="capex-quarterly-field">
        <%= f.label :q1_amount, 'Q1 Amount' %>
        <%= f.number_field :q1_amount, required: true, step: 0.01, min: 0, class: 'form-control quarterly-input' %>
      </div>
      <div class="capex-quarterly-field">
        <%= f.label :q2_amount, 'Q2 Amount' %>
        <%= f.number_field :q2_amount, required: true, step: 0.01, min: 0, class: 'form-control quarterly-input' %>
      </div>
      <div class="capex-quarterly-field">
        <%= f.label :q3_amount, 'Q3 Amount' %>
        <%= f.number_field :q3_amount, required: true, step: 0.01, min: 0, class: 'form-control quarterly-input' %>
      </div>
      <div class="capex-quarterly-field">
        <%= f.label :q4_amount, 'Q4 Amount' %>
        <%= f.number_field :q4_amount, required: true, step: 0.01, min: 0, class: 'form-control quarterly-input' %>
      </div>
    </div>

    <div class="quarterly-validation">
      <div class="capex-total-validation" id="quarterly-validation"></div>
    </div>
  </div>

  <div class="form-section">
    <div class="form-section-title">Notes</div>

    <div class="form-row">
      <%= f.label :notes, 'Notes' %>
      <%= f.text_area :notes, rows: 3, class: 'form-control' %>
      <em class="info">Optional notes or comments about this CAPEX entry</em>
    </div>
  </div>

  <div class="pr-form-actions">
    <%= f.submit class: 'pr-button pr-button-primary' %>
    <%= link_to 'Cancel', project_capex_index_path(@project), class: 'pr-button pr-button-cancel' %>
  </div>
<% end %>
```

Then KEEP the existing `<script> … </script>` block (lines 147-233 of the current file) verbatim immediately after `<% end %>`. Do not modify it — it references `capex_total_amount`, `.quarterly-input`, `quarterly-validation`, `capex_tpc_code_id`, `capex_tpc_code`, `.tpc-code-field`, all of which are preserved above.

- [ ] **Step 2: Verify wrappers**

`capex/new.html.erb` and `capex/edit.html.erb` already match CANON-B (header with `.pr-form-title` > `h2`, instructions on `new`, `pr-form-box` > `render 'form'`). No change needed. Confirm by reading both files; if either has a stray bare `<h2>` above `.pr-form-container`, remove it.

- [ ] **Step 3: Verify**

`touch tmp/restart.txt`. Open CAPEX `new` and `edit`. Expected: HTTP 200; four flat sections; the TPC-code interaction still works (selecting a TPC code disables/fills the legacy field); entering a total still prompts to distribute across quarters; the quarterly-sum validation message still appears.

- [ ] **Step 4: Commit**

```bash
git add app/views/capex/_form.html.erb app/views/capex/new.html.erb app/views/capex/edit.html.erb
git commit -m "style: normalize CAPEX form field markup"
```

---

## Task 5: OPEX form

OPEX inlines its whole form in `new.html.erb`, and `edit.html.erb` duplicates it. Extract a `_form.html.erb` partial (CANON-A) and the form `<script>` moves into it so both actions share one source.

**Files:**
- Create: `app/views/opex/_form.html.erb`
- Modify: `app/views/opex/new.html.erb`
- Modify: `app/views/opex/edit.html.erb`

- [ ] **Step 1: Create `app/views/opex/_form.html.erb`**

The partial owns `form_with`, the error block, sections, actions, and the quarterly-validation `<script>`. The form URL/method branch on `@opex.new_record?`. Full content:

```erb
<%= form_with model: [@project, @opex],
              url: (@opex.new_record? ? project_opex_index_path(@project) : project_opex_path(@project, @opex)),
              method: (@opex.new_record? ? :post : :patch),
              local: true, html: { class: 'opex-form' } do |f| %>
  <% if @opex.errors.any? %>
    <div class="pr-alert pr-alert-danger">
      <span class="icon icon-warning"></span>
      <div class="pr-alert-content">
        <h4><%= pluralize(@opex.errors.count, 'error') %> prohibited this OPEX entry from being saved:</h4>
        <ul>
          <% @opex.errors.full_messages.each do |message| %>
            <li><%= message %></li>
          <% end %>
        </ul>
      </div>
    </div>
  <% end %>

  <div class="form-section">
    <div class="form-section-title">General Information</div>

    <div class="pr-field-pair">
      <div class="form-row">
        <%= f.label :year, l(:field_opex_year) %> <span class="required">*</span>
        <%= f.number_field :year, min: 2000, max: 2100, required: true, value: @opex.year, class: 'form-control' %>
      </div>
      <div class="form-row">
        <%= f.label :description, l(:field_opex_description) %> <span class="required">*</span>
        <%= f.text_field :description, required: true, class: 'form-control' %>
      </div>
    </div>

    <div class="pr-field-pair">
      <div class="form-row">
        <%= f.label :total_amount, l(:field_opex_total_amount) %> <span class="required">*</span>
        <%= f.number_field :total_amount, step: 0.01, min: 0, required: true, class: 'form-control' %>
      </div>
      <div class="form-row">
        <%= f.label :currency, l(:field_opex_currency) %> <span class="required">*</span>
        <%= f.select :currency,
                     options_for_select([
                       ['USD - US Dollar', 'USD'], ['EUR - Euro', 'EUR'], ['GBP - British Pound', 'GBP'],
                       ['JPY - Japanese Yen', 'JPY'], ['CAD - Canadian Dollar', 'CAD'], ['AUD - Australian Dollar', 'AUD'],
                       ['CHF - Swiss Franc', 'CHF'], ['CNY - Chinese Yuan', 'CNY'], ['SEK - Swedish Krona', 'SEK'],
                       ['NZD - New Zealand Dollar', 'NZD'], ['MXN - Mexican Peso', 'MXN'], ['SGD - Singapore Dollar', 'SGD'],
                       ['HKD - Hong Kong Dollar', 'HKD'], ['IDR - Indonesian Rupiah', 'IDR'], ['NOK - Norwegian Krone', 'NOK'],
                       ['KRW - South Korean Won', 'KRW'], ['TRY - Turkish Lira', 'TRY'], ['RUB - Russian Ruble', 'RUB'],
                       ['INR - Indian Rupee', 'INR'], ['BRL - Brazilian Real', 'BRL'], ['ZAR - South African Rand', 'ZAR']
                     ], @opex.currency), { required: true }, { class: 'form-control' } %>
      </div>
    </div>

    <div class="pr-field-pair">
      <div class="form-row">
        <%= f.label :category_id, l(:field_opex_category) %> <span class="required">*</span>
        <%= f.collection_select :category_id, OpexCategory.all, :id, :name,
                               { prompt: 'Select a category' },
                               { required: true, class: 'form-control' } %>
      </div>
      <div class="form-row">
        <%= f.label :tpc_code_id, 'TPC Code' %>
        <%= f.collection_select :tpc_code_id,
                               TpcCode.available_for_project(@project).active.ordered,
                               :id, :tpc_number_with_description,
                               { include_blank: 'Select TPC Code (optional)' },
                               { class: 'form-control', id: 'opex_tpc_code_id' } %>
        <em class="info">Link this OPEX entry to a TPC code for tracking (owner and budget responsibility)</em>
      </div>
    </div>

    <div class="pr-field-pair">
      <div class="form-row opex-code-field">
        <%= f.label :opex_code, l(:field_opex_code) %>
        <%= f.text_field :opex_code, id: 'opex_opex_code', class: 'form-control' %>
        <em class="info">Legacy OPEX code (only required if no TPC code is selected above)</em>
      </div>
      <div class="form-row">
        <%= f.label :cost_center, l(:field_opex_cost_center) %>
        <%= f.text_field :cost_center, class: 'form-control' %>
      </div>
    </div>
  </div>

  <div class="form-section">
    <div class="form-section-title">Quarterly Distribution</div>

    <div class="pr-alert pr-alert-info">
      <span class="icon icon-info"></span>
      <div class="pr-alert-content">
        Distribute the total amount across quarters. The sum of all quarters must equal the total amount.
      </div>
    </div>

    <div class="capex-quarterly-grid">
      <div class="capex-quarterly-field">
        <%= f.label :q1_amount, l(:field_opex_q1_amount) %>
        <%= f.number_field :q1_amount, step: 0.01, min: 0, class: 'form-control quarterly-input' %>
      </div>
      <div class="capex-quarterly-field">
        <%= f.label :q2_amount, l(:field_opex_q2_amount) %>
        <%= f.number_field :q2_amount, step: 0.01, min: 0, class: 'form-control quarterly-input' %>
      </div>
      <div class="capex-quarterly-field">
        <%= f.label :q3_amount, l(:field_opex_q3_amount) %>
        <%= f.number_field :q3_amount, step: 0.01, min: 0, class: 'form-control quarterly-input' %>
      </div>
      <div class="capex-quarterly-field">
        <%= f.label :q4_amount, l(:field_opex_q4_amount) %>
        <%= f.number_field :q4_amount, step: 0.01, min: 0, class: 'form-control quarterly-input' %>
      </div>
    </div>

    <div id="quarterly-validation" style="margin-top:12px;"></div>
  </div>

  <div class="form-section">
    <div class="form-section-title">Notes</div>

    <div class="form-row">
      <%= f.label :notes, l(:field_opex_notes) %>
      <%= f.text_area :notes, rows: 3, class: 'form-control' %>
    </div>
  </div>

  <div class="pr-form-actions">
    <%= f.submit (@opex.new_record? ? l(:button_create) : l(:button_save)), class: 'pr-button pr-button-primary' %>
    <%= link_to l(:button_cancel), project_opex_index_path(@project), class: 'pr-button pr-button-cancel' %>
  </div>
<% end %>

<script>
document.addEventListener('DOMContentLoaded', function() {
  var tpcCodeSelect = document.getElementById('opex_tpc_code_id');
  var opexCodeInput = document.getElementById('opex_opex_code');
  var opexCodeField = opexCodeInput ? opexCodeInput.closest('.opex-code-field') : null;
  var totalAmountInput = document.querySelector('input[name="opex[total_amount]"]');
  var quarterlyInputs = document.querySelectorAll('.quarterly-input');
  var validationDiv = document.getElementById('quarterly-validation');

  function updateOpexCodeFields() {
    if (!tpcCodeSelect || !opexCodeInput) return;
    var tpcCodeSelected = tpcCodeSelect.value && tpcCodeSelect.value !== '';
    if (tpcCodeSelected) {
      if (opexCodeField) opexCodeField.style.opacity = '0.6';
      opexCodeInput.disabled = true;
      opexCodeInput.required = false;
      opexCodeInput.placeholder = 'TPC code will be used';
    } else {
      if (opexCodeField) opexCodeField.style.opacity = '1';
      opexCodeInput.disabled = false;
      opexCodeInput.required = true;
      opexCodeInput.placeholder = 'Enter OPEX code or leave blank for auto-generation';
    }
  }

  function validateQuarterlyAmounts() {
    if (!totalAmountInput || !validationDiv) return;
    var totalAmount = parseFloat(totalAmountInput.value) || 0;
    var quarterlySum = 0;
    quarterlyInputs.forEach(function(input) {
      quarterlySum += parseFloat(input.value) || 0;
    });
    var difference = Math.abs(totalAmount - quarterlySum);

    while (validationDiv.firstChild) { validationDiv.removeChild(validationDiv.firstChild); }

    if (totalAmount === 0) return;

    var alertDiv = document.createElement('div');
    var contentDiv = document.createElement('div');
    contentDiv.className = 'pr-alert-content';
    var textNode;

    if (difference < 0.01) {
      alertDiv.className = 'pr-alert pr-alert-success';
      textNode = document.createTextNode('✓ Quarterly amounts sum equals total amount');
    } else {
      alertDiv.className = 'pr-alert pr-alert-warning';
      var shortfall = totalAmount - quarterlySum;
      var msg = shortfall > 0
        ? '⚠ Missing ' + shortfall.toFixed(2) + ' from quarterly distribution'
        : '⚠ Quarterly amounts exceed total by ' + Math.abs(shortfall).toFixed(2);
      textNode = document.createTextNode(msg);
    }
    contentDiv.appendChild(textNode);
    alertDiv.appendChild(contentDiv);
    validationDiv.appendChild(alertDiv);
  }

  updateOpexCodeFields();
  validateQuarterlyAmounts();

  if (tpcCodeSelect) tpcCodeSelect.addEventListener('change', updateOpexCodeFields);
  if (totalAmountInput) totalAmountInput.addEventListener('input', validateQuarterlyAmounts);
  quarterlyInputs.forEach(function(input) {
    input.addEventListener('input', validateQuarterlyAmounts);
  });
});
</script>
```

Note: the `<script>` is copied verbatim from the current `opex/new.html.erb` (the `✓`/`⚠` above represent the existing literal ✓ and ⚠ characters — keep whatever characters the source uses).

- [ ] **Step 2: Rewrite `new.html.erb`**

```erb
<%# filepath: app/views/opex/new.html.erb %>
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
  <%= javascript_include_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title "New OPEX Entry - #{@project.name}" %>

<div class="contextual">
  <%= link_to project_opex_index_path(@project), class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel">Back to OPEX List</span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2>New OPEX Entry</h2>
      <div class="pr-form-subtitle">
        <span class="icon icon-info"></span>
        <%= @project.name %>
      </div>
    </div>
  </div>

  <div class="pr-form-instructions">
    <div class="pr-alert pr-alert-info">
      <span class="icon icon-info"></span>
      <div class="pr-alert-content">
        <h4>Create New OPEX Entry</h4>
        <p>Fill in the details below to create a new OPEX budget entry. Quarterly amounts must sum to the total amount.</p>
      </div>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= render 'form' %>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Rewrite `edit.html.erb`**

```erb
<%# filepath: app/views/opex/edit.html.erb %>
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
  <%= javascript_include_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title "Edit OPEX Entry - #{@project.name}" %>

<div class="contextual">
  <%= link_to project_opex_index_path(@project), class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel">Back to OPEX List</span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2>Edit OPEX Entry</h2>
      <div class="pr-form-subtitle">
        <span class="icon icon-edit"></span>
        <%= @project.name %>
      </div>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= render 'form' %>
    </div>
  </div>
</div>
```

- [ ] **Step 4: Verify**

`touch tmp/restart.txt`. Open OPEX `new` and `edit`. Expected: HTTP 200; single title (the old duplicate bare `<h2>` is gone); four flat sections; selecting a TPC code disables the legacy OPEX-code field; the quarterly-sum alert updates live. Submit a new OPEX entry — it saves.

- [ ] **Step 5: Commit**

```bash
git add app/views/opex/_form.html.erb app/views/opex/new.html.erb app/views/opex/edit.html.erb
git commit -m "refactor: extract shared OPEX _form partial and unify styling"
```

---

## Task 6: TPC Codes form

The TPC form is inlined in `new.html.erb`; `edit.html.erb` is `render template: 'tpc_codes/new'`. Extract a `_form.html.erb` partial and give `edit` a real wrapper.

**Files:**
- Create: `app/views/tpc_codes/_form.html.erb`
- Modify: `app/views/tpc_codes/new.html.erb`
- Modify: `app/views/tpc_codes/edit.html.erb`

- [ ] **Step 1: Create `app/views/tpc_codes/_form.html.erb`**

```erb
<%= form_with model: @tpc_code,
              url: (@tpc_code.new_record? ?
                    (@project ? project_tpc_codes_path(@project) : global_tpc_codes_path) :
                    (@project ? project_tpc_code_path(@project, @tpc_code) : global_tpc_code_path(@tpc_code))),
              method: (@tpc_code.new_record? ? :post : :patch),
              local: true, html: { class: 'tpc-code-form' } do |f| %>
  <% if @tpc_code.errors.any? %>
    <div class="pr-alert pr-alert-danger">
      <span class="icon icon-warning"></span>
      <div class="pr-alert-content">
        <h4><%= pluralize(@tpc_code.errors.count, 'error') %> prohibited this TPC code from being saved:</h4>
        <ul>
          <% @tpc_code.errors.full_messages.each do |message| %>
            <li><%= message %></li>
          <% end %>
        </ul>
      </div>
    </div>
  <% end %>

  <div class="form-section">
    <div class="form-section-title">TPC Code Details</div>

    <div class="pr-field-pair">
      <div class="form-row">
        <%= f.label :tpc_number %> <span class="required">*</span>
        <%= f.text_field :tpc_number, required: true, maxlength: 50, class: 'form-control' %>
        <em class="info">Unique TPC number (e.g., TPC-2025-001)</em>
      </div>
      <div class="form-row">
        <%= f.label :tpc_owner_name %> <span class="required">*</span>
        <%= f.text_field :tpc_owner_name, required: true, maxlength: 100, class: 'form-control' %>
        <em class="info">Full name of the TPC owner</em>
      </div>
    </div>

    <div class="pr-field-pair">
      <div class="form-row">
        <%= f.label :department %>
        <%= f.text_field :department, maxlength: 100, class: 'form-control' %>
        <em class="info">Department name (optional)</em>
      </div>
      <div class="form-row">
        <%= f.label :tpc_email %> <span class="required">*</span>
        <%= f.email_field :tpc_email, required: true, maxlength: 255, class: 'form-control' %>
        <em class="info">Email address of the TPC owner</em>
      </div>
    </div>

    <div class="form-row">
      <%= f.label :description %>
      <%= f.text_area :description, rows: 3, maxlength: 1000, class: 'form-control' %>
      <em class="info">Brief description of the TPC code purpose (optional)</em>
    </div>

    <div class="form-row">
      <%= f.label :notes %>
      <%= f.text_area :notes, rows: 4, maxlength: 2000, class: 'form-control' %>
      <em class="info">Additional notes or comments (optional)</em>
    </div>

    <div class="form-row">
      <div class="pr-check">
        <%= f.check_box :is_active %>
        <%= f.label :is_active %>
        <em class="info">Uncheck to deactivate this TPC code</em>
      </div>
    </div>
  </div>

  <% if @project %>
    <div class="pr-scope-note">
      <span class="scope-badge project">Project</span>
      <span>This TPC code will be specific to the &ldquo;<%= @project.name %>&rdquo; project.</span>
    </div>
  <% else %>
    <div class="pr-scope-note">
      <span class="scope-badge global">Global</span>
      <span>This TPC code will be available to all projects.</span>
    </div>
  <% end %>

  <div class="pr-form-actions">
    <%= f.submit (@tpc_code.new_record? ? l(:button_create) : l(:button_save)), class: 'pr-button pr-button-primary' %>
    <%= link_to l(:button_cancel),
                (@project ? project_tpc_codes_path(@project) : global_tpc_codes_path),
                class: 'pr-button pr-button-cancel' %>
  </div>
<% end %>
```

- [ ] **Step 2: Rewrite `new.html.erb`**

```erb
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
  <%= javascript_include_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title "New TPC Code" %>

<div class="contextual">
  <%= link_to (@project ? project_tpc_codes_path(@project) : global_tpc_codes_path), class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel">Back to TPC Codes</span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2>New TPC Code</h2>
      <div class="pr-form-subtitle">
        <span class="icon icon-info"></span>
        <%= @project ? @project.name : 'Global' %>
      </div>
    </div>
  </div>

  <div class="pr-form-instructions">
    <div class="pr-alert pr-alert-info">
      <span class="icon icon-info"></span>
      <div class="pr-alert-content">
        <h4>Create New TPC Code</h4>
        <p>Register a Total Project Cost code with its owner and contact details.</p>
      </div>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= render 'form' %>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Rewrite `edit.html.erb`**

Replace the `render template: 'tpc_codes/new'` delegation with a real edit wrapper:

```erb
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
  <%= javascript_include_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title "Edit TPC Code" %>

<div class="contextual">
  <%= link_to (@project ? project_tpc_codes_path(@project) : global_tpc_codes_path), class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel">Back to TPC Codes</span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2>Edit TPC Code</h2>
      <div class="pr-form-subtitle">
        <span class="icon icon-edit"></span>
        <%= @tpc_code.tpc_number %>
      </div>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= render 'form' %>
    </div>
  </div>
</div>
```

- [ ] **Step 4: Verify**

`touch tmp/restart.txt`. Open TPC `new` (both a project-scoped URL and, if `tpc_global_enabled`, the global URL) and `edit`. Expected: HTTP 200; single title; one flat section; the scope note shows the correct GLOBAL/PROJECT badge; `is_active` renders as a `.pr-check` row. Submit — it saves.

- [ ] **Step 5: Commit**

```bash
git add app/views/tpc_codes/_form.html.erb app/views/tpc_codes/new.html.erb app/views/tpc_codes/edit.html.erb
git commit -m "refactor: extract shared TPC code _form partial and unify styling"
```

---

## Task 7: Vendors form

Three divergent copies exist: the `_form.html.erb` partial (`box tabular`, no `form-control`), and inline forms with their own `<style>` blocks in `vendors/new.html.erb` and `project_vendors/new.html.erb`. Collapse to ONE canonical `_form.html.erb` used by all three wrappers.

**Files:**
- Modify: `app/views/vendors/_form.html.erb`
- Modify: `app/views/vendors/new.html.erb`
- Modify: `app/views/vendors/edit.html.erb`
- Modify: `app/views/project_vendors/new.html.erb`

- [ ] **Step 1: Rewrite `vendors/_form.html.erb` as the canonical partial**

The partial contains only the sections + fields (NOT `form_with`, NOT actions — see Step 2 rationale). It is rendered inside the wrapper's `form_with` block, receiving `f` as a local. Full content:

```erb
<% if @vendor.errors.any? %>
  <div class="pr-alert pr-alert-danger">
    <span class="icon icon-warning"></span>
    <div class="pr-alert-content">
      <h4><%= pluralize(@vendor.errors.count, 'error') %> prohibited this vendor from being saved:</h4>
      <ul>
        <% @vendor.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  </div>
<% end %>

<div class="form-section">
  <div class="form-section-title">Basic Information</div>

  <div class="pr-field-pair">
    <div class="form-row">
      <%= f.label :name, l(:field_vendor_name) %> <span class="required">*</span>
      <%= f.text_field :name, required: true, class: 'form-control' %>
      <em class="info">The name of the vendor or company.</em>
    </div>
    <div class="form-row">
      <%= f.label :vendor_id, l(:field_vendor_id) %>
      <%= f.text_field :vendor_id, class: 'form-control' %>
      <em class="info">Optional vendor ID or code.</em>
    </div>
  </div>

  <div class="pr-field-pair">
    <div class="form-row">
      <%= f.label :email, l(:field_email) %>
      <%= f.email_field :email, class: 'form-control' %>
      <em class="info">Primary contact email.</em>
    </div>
    <div class="form-row">
      <%= f.label :phone, l(:field_phone) %>
      <%= f.telephone_field :phone, class: 'form-control' %>
      <em class="info">Primary contact phone number.</em>
    </div>
  </div>

  <div class="pr-field-pair">
    <div class="form-row">
      <%= f.label :contact_person, l(:field_contact_person) %>
      <%= f.text_field :contact_person, class: 'form-control' %>
      <em class="info">Name of primary contact person.</em>
    </div>
    <div class="form-row">
      <%= f.label :website, l(:field_website) %>
      <%= f.url_field :website, class: 'form-control' %>
      <em class="info">Company website URL.</em>
    </div>
  </div>
</div>

<div class="form-section">
  <div class="form-section-title">Location &amp; Additional Information</div>

  <div class="pr-field-pair">
    <div class="form-row">
      <%= f.label :country, l(:field_country) %>
      <% countries = [
        ['-- Unspecified --', '']
        # ... see Step 1a
      ] %>
      <%= f.select :country, countries, {}, { class: 'form-control' } %>
      <em class="info">Country where vendor is located.</em>
    </div>
    <div class="form-row">
      <%= f.label :address, l(:field_address) %>
      <%= f.text_area :address, rows: 3, class: 'form-control' %>
      <em class="info">Company address.</em>
    </div>
  </div>

  <div class="form-row">
    <%= f.label :notes, l(:field_notes) %>
    <%= f.text_area :notes, rows: 4, class: 'form-control' %>
    <em class="info">Additional notes or comments about this vendor.</em>
  </div>

  <div class="form-row">
    <div class="pr-check">
      <%= f.check_box :is_active %>
      <%= f.label :is_active, l(:field_is_active) %>
      <em class="info">Uncheck to mark vendor as inactive.</em>
    </div>
  </div>
</div>
```

- [ ] **Step 1a: Fill in the `countries` array**

Replace the `countries = [ … ]` literal above with the full array copied **verbatim** from the current `app/views/vendors/new.html.erb` (the `countries = [ … ]` block, ~200 entries, beginning `['-- Unspecified --', '']` and ending `['Zimbabwe', 'Zimbabwe']`). Do not retype the list — copy it exactly to avoid typos.

- [ ] **Step 2: Rewrite `vendors/new.html.erb`**

The wrapper owns `form_with`, the scope note, and `.pr-form-actions`; it renders the partial for the field sections. Delete the entire trailing inline `<style>` block. Full content:

```erb
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
  <%= javascript_include_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title "New Global Vendor" %>

<div class="contextual">
  <%= link_to vendors_path, class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel">Back to Vendor List</span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2>New Global Vendor</h2>
      <div class="pr-form-subtitle">
        <span class="icon icon-info"></span>
        Available to all projects
      </div>
    </div>
  </div>

  <div class="pr-form-instructions">
    <div class="pr-alert pr-alert-info">
      <span class="icon icon-info"></span>
      <div class="pr-alert-content">
        <h4>Creating a Global Vendor</h4>
        <p>This vendor will be available to all projects in the system and managed centrally.</p>
      </div>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= form_with model: @vendor, local: true, html: { class: 'vendor-form' } do |f| %>
        <%= render partial: 'form', locals: { f: f } %>

        <div class="pr-scope-note">
          <span class="scope-badge global">Global</span>
          <span>This vendor will be available to all projects in the system.</span>
        </div>

        <div class="pr-form-actions">
          <%= f.submit "Create Global Vendor", class: 'pr-button pr-button-primary' %>
          <%= link_to "Cancel", vendors_path, class: 'pr-button pr-button-cancel' %>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Rewrite `vendors/edit.html.erb`**

Keep the existing project-aware back-link / "View Vendor" logic, but move it into the standard structure and render the shared partial. Full content:

```erb
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
  <%= javascript_include_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title "Edit Global Vendor - #{@vendor.name}" %>
<% back_path = params[:project_id].present? && Project.find_by(id: params[:project_id]) ? project_vendors_path(params[:project_id]) : vendors_path %>
<% view_path = params[:project_id].present? ? vendor_path(@vendor, project_id: params[:project_id]) : vendor_path(@vendor) %>

<div class="contextual">
  <%= link_to back_path, class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel">Back to Vendor List</span>
  <% end %>
  <%= link_to view_path, class: 'pr-button pr-button-secondary pr-button-icon small' do %>
    <span class="icon icon-magnifier">View Vendor</span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2>Edit Global Vendor</h2>
      <div class="pr-form-subtitle">
        <span class="icon icon-edit"></span>
        <%= @vendor.name %>
      </div>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= form_with model: @vendor, local: true, html: { class: 'vendor-form' } do |f| %>
        <%= render partial: 'form', locals: { f: f } %>

        <div class="pr-form-actions">
          <%= f.submit "Update Vendor", class: 'pr-button pr-button-primary' %>
          <%= link_to "Cancel", back_path, class: 'pr-button pr-button-cancel' %>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 4: Rewrite `project_vendors/new.html.erb`**

Same pattern; project-scoped. Delete the inline `info-box`/`errorExplanation` markup (the partial's CANON-E block handles errors). Full content:

```erb
<% content_for :header_tags do %>
  <%= stylesheet_link_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
  <%= javascript_include_tag 'purchase_requests', plugin: 'redmine_purchase_requests' %>
<% end %>

<% html_title "New Project Vendor - #{@project.name}" %>

<div class="contextual">
  <%= link_to project_vendors_path(@project), class: 'pr-button pr-button-cancel pr-button-icon small' do %>
    <span class="icon icon-cancel">Back to Vendor List</span>
  <% end %>
  <%= link_to vendors_path, class: 'pr-button pr-button-secondary pr-button-icon small' do %>
    <span class="icon icon-settings">Global Vendors</span>
  <% end %>
</div>

<div class="pr-form-container">
  <div class="pr-form-header">
    <div class="pr-form-title">
      <h2>New Project Vendor</h2>
      <div class="pr-form-subtitle">
        <span class="icon icon-info"></span>
        <%= @project.name %>
      </div>
    </div>
  </div>

  <div class="pr-form-instructions">
    <div class="pr-alert pr-alert-info">
      <span class="icon icon-info"></span>
      <div class="pr-alert-content">
        <h4>Creating a Project Vendor</h4>
        <p>This vendor will be associated with the &ldquo;<%= @project.name %>&rdquo; project.</p>
      </div>
    </div>
  </div>

  <div class="pr-form-box">
    <div class="pr-form-content">
      <%= form_with model: [@project, @vendor], local: true, html: { class: 'vendor-form' } do |f| %>
        <%= render partial: 'form', locals: { f: f } %>

        <div class="pr-scope-note">
          <span class="scope-badge project">Project</span>
          <span>This vendor will be associated with the &ldquo;<%= @project.name %>&rdquo; project.</span>
        </div>

        <div class="pr-form-actions">
          <%= f.submit "Create Project Vendor", class: 'pr-button pr-button-primary' %>
          <%= link_to "Cancel", project_vendors_path(@project), class: 'pr-button pr-button-cancel' %>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

- [ ] **Step 5: Verify**

Run: `grep -rn "<style>\|vendor-form-section\|form-help\|#007bff" app/views/vendors/ app/views/project_vendors/`
Expected: no matches — all inline CSS and bespoke classes are gone.

`touch tmp/restart.txt`. Open: global vendor `new`, vendor `edit` (both via the global list and via a project's vendor list so `project_id` is set), and project vendor `new`. Expected on each: HTTP 200; single title; two flat sections; scope badge present where applicable; submit saves the vendor.

- [ ] **Step 6: Commit**

```bash
git add app/views/vendors/_form.html.erb app/views/vendors/new.html.erb app/views/vendors/edit.html.erb app/views/project_vendors/new.html.erb
git commit -m "refactor: consolidate vendor forms onto one partial, remove inline CSS"
```

---

## Task 8: Purchase Request form

The PR form (`purchase_requests/_form.html.erb`, ~45 KB, tabbed) keeps its tab + stepper structure. Apply field-markup normalization only; it already uses `.pr-form-box`, `.pr-tabs`, and `.pr-form-content`.

**Files:**
- Modify: `app/views/purchase_requests/_form.html.erb`
- Modify: `app/views/purchase_requests/new.html.erb` (only if drift is found)
- Modify: `app/views/purchase_requests/edit.html.erb` (only if drift is found)

- [ ] **Step 1: Survey the drift**

Run each and inspect every hit:
```bash
grep -n "class: 'required'\|class: \"required\"" app/views/purchase_requests/_form.html.erb
grep -n "form-help\|<small" app/views/purchase_requests/_form.html.erb
grep -n "<style" app/views/purchase_requests/_form.html.erb app/views/purchase_requests/new.html.erb app/views/purchase_requests/edit.html.erb
grep -n "<h2" app/views/purchase_requests/new.html.erb app/views/purchase_requests/edit.html.erb
```

- [ ] **Step 2: Apply the normalization rules**

For each hit from Step 1, edit in place:
- **Required marker:** remove `class: 'required'` from any `f.label`/`label` tag. Ensure the field still has a `<span class="required">*</span>` immediately after the label; add one if missing and the field is required.
- **Helper text:** replace any `<small class="form-help">…</small>` with `<em class="info">…</em>`. Replace any other `<small>`-based hint with `<em class="info">`.
- **Inline styles:** if Step 1 found a `<style>` block, move its rules into `assets/stylesheets/purchase_requests.css` (scoped under `#content`) and delete the block. If no `<style>` block was found, skip.
- **Duplicate title:** if `new.html.erb` or `edit.html.erb` has a bare `<h2>` above `.pr-form-container`, remove it (the `.pr-form-title > h2` inside the header is the single title).
- **Checkbox rows:** if a checkbox field is wrapped in an ad-hoc container (e.g. `.checkbox-group`), convert it to the CANON-D checkbox pattern (`<div class="pr-check">`).

Do NOT change: the tab structure (`.pr-tabs`, `.pr-tab-nav`, `.tab-pane`), the stepper, field names, the `form_for`/`form_with` call, routes, or the page `<script>`.

- [ ] **Step 3: Verify**

Re-run the Step 1 greps. Expected: no `class: 'required'` on labels, no `form-help`/`<small>` hints, no `<style>` blocks, no duplicate `<h2>`.

`touch tmp/restart.txt`. Open PR `new` and `edit`. Expected: HTTP 200; tabs still switch; stepper still advances; sections render with the flat treatment; submit creates/updates a request.

- [ ] **Step 4: Commit**

```bash
git add app/views/purchase_requests/_form.html.erb app/views/purchase_requests/new.html.erb app/views/purchase_requests/edit.html.erb
git commit -m "style: normalize purchase request form field markup"
```

---

## Task 9: Regression sweep

`.form-row`, `.form-control`, and `.form-section` are shared with non-form views. Confirm the CSS rework did not break them.

**Files:** none modified unless a regression is found.

- [ ] **Step 1: Find other consumers of the shared classes**

Run:
```bash
grep -rln "form-section\|form-row\|form-control" app/views --include=*.erb | grep -vE "(capex|opex|tpc_codes|vendors|project_vendors|purchase_request_statuses|purchase_request_workflow_templates|purchase_requests)/" 
```

- [ ] **Step 2: Visually check each**

`touch tmp/restart.txt`. Open each view from Step 1 (settings partials are reached via Administration → Plugins → Configure). Expected: no nested grey card is missing in a way that looks broken; section titles read as uppercase labels; inputs are styled. The flat `.form-section` is acceptable everywhere; if any view depended on the old grey card as a visual container and now looks unframed, wrap that view's group in `.pr-form-box` instead — do not revert the shared rule.

- [ ] **Step 3: Run the plugin test suite (if present)**

Run: `bundle exec rake test:plugins NAME=redmine_purchase_requests RAILS_ENV=test`
Expected: no NEW failures versus a pre-change baseline. View-only changes should not affect controller/unit tests. If the suite does not exist or cannot run in this environment, note that and rely on the manual render checks.

- [ ] **Step 4: Final commit (only if Step 2 required a fix)**

```bash
git add <files-changed-in-step-2>
git commit -m "fix: reframe <view> after shared form CSS rework"
```

---

## Self-Review Notes

- **Spec coverage:** sectioned-panel treatment → Task 1; standard page structure → Tasks 2-7 (CANON-B); field components → Task 1 CSS + CANON-D in every form task; Vendors rebuild → Task 7; partial consolidation (OPEX/TPC/Vendors) → Tasks 5/6/7; PR form normalization → Task 8; shared-CSS regression risk → Task 9. All spec sections map to a task.
- **No placeholders:** the only "copy verbatim" instruction is the 200-entry `countries` array (Step 1a) — copying an existing literal is correct and avoids transcription errors; it is not a vague placeholder.
- **Naming consistency:** every form uses `form-section`, `form-section-title`, `form-row`, `pr-field-pair`, `form-control`, `pr-check`, `pr-form-actions`, `pr-form-box`, `pr-form-content`, `pr-form-header`, `pr-form-title`, `pr-form-subtitle`, `pr-scope-note`, `scope-badge` — matching the CSS added in Task 1.
- **JS preservation:** CAPEX (Task 4) and OPEX (Task 5) keep their `<script>` blocks and all element IDs/classes the scripts target; PR tabs/stepper (Task 8) are explicitly untouched.
