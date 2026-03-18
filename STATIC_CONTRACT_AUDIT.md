# Static contract audit

Date: 2026-03-18 (UTC)

## Gate result

**Do not treat the restored SQL snapshot as authoritative yet, and do not push it to GitHub.**

This repo does **not** currently contain `029_full_app_schema.sql` or `027_rls_policies.sql`, so the requested source-of-truth comparison is blocked. I completed a provisional static audit against the files that do exist (`_worker.js`, `index.html`, and `002_seed.sql`) and found multiple contract mismatches.

## 1) `_worker.js` table and field inventory

This inventory lists tables and directly referenced fields visible in `_worker.js`.

- `assets`: `asset_id`, `name`, `category`, `rig_name`, `location`, `status`, `serial`, `notes`, `last_inspection`, `inspection_type`, `cert_link`, `client_id`, `updated_at`
- `rigs`: `id`, `name`, `rig_name`, `type`, `location`, `depth`, `hp`, `status`, `notes`, `client_id`, `updated_at`
- `contracts`: `id`, `rig_id`, `rig`, `value`, `start_date`, `end_date`, `status`, `notes`, `contract_assets`, `updated_at`
- `contract_assets`: `asset_id`
- `bom_items`: `id`, `asset_id`, `parent_id`, `name`, `part_no`, `type`, `serial`, `manufacturer`, `qty`, `uom`, `unit_cost`, `lead_time`, `status`, `notes`, `created_at`, `updated_at`
- `certificates`: `cert_id`, `asset_id`, `inspection_type`, `last_inspection`, `next_inspection`, `validity_days`, `alert_days`, `cert_link`, `notes`, `name`, `serial`, `rig_name`, `category`, `client_id`, `updated_at`
- `maintenance_schedules`: `id`, `asset_id`, `task`, `type`, `priority`, `freq`, `last_done`, `next_due`, `tech`, `hours`, `cost`, `status`, `alert_days`, `notes`, `updated_at`
- `maintenance_logs`: `schedule_id`, `completion_date`, `performed_by`, `hours`, `cost`, `parts_used`, `notes`
- `transfers`: `id`, `asset_id`, `asset_name`, `current_loc`, `destination`, `dest_rig`, `priority`, `type`, `requested_by`, `request_date`, `required_date`, `reason`, `instructions`, `status`, `supt_approved_by`, `supt_approved_date`, `supt_action`, `supt_comment`, `ops_approved_by`, `ops_approved_date`, `ops_action`, `ops_comment`, `mgr_approved_by`, `mgr_approved_date`, `mgr_action`, `mgr_comment`, `bom_item_id`, `bom_item_name`, `bom_part_no`, `vendor_name`, `vendor_type`, `po_number`, `vendor_contact`, `return_date`, `client_id`, `updated_at`
- `app_users`: `id`, `name`, `role`, `dept`, `email`, `color`, `initials`, `password`, `active`, `client_id`, `password_changed_at`, `updated_at`
- `notifications`: `id`, `title`, `description`, `icon`, `kind`, `link`, `user_id`, `client_id`, `event_type`, `is_read`, `created_at`
- `clients`: `id`, `name`, `code`, `active`, `updated_at`
- `delete_requests`: `id`, `resource`, `record_id`, `record_label`, `requested_by_user_id`, `requested_by_name`, `requested_by_role`, `reason`, `status`, `created_at`, `reviewed_by_user_id`, `reviewed_by_name`, `reviewed_at`, `review_comment`, `updated_at`
- `inspections`: `id`, `po_number`, `service_order`, `start_date`, `rig_name`, `inspection_type`, `end_date`, `notes`, `updated_at`
- `projects`: `project_id`, `description`, `status`, `priority`, `rig_name`, `location`, `manager`, `supervisor_name`, `supervisor_contact`, `initiation_date`, `start_date`, `end_date`, `progress`, `notes`, `budget`, `spent`, `created_at`, `updated_at`
- `workshops`: `workshop_id`, `workshop_name`, `name`, `location`, `assigned_rig`, `asset_id`, `asset_name`, `asset_serial`, `scope_of_work`, `start_date`, `end_date`, `status`, `technician`, `contact`, `notes`, `created_at`, `updated_at`
- `push_subscriptions`: `id`, `user_id`, `client_id`, `endpoint`, `p256dh`, `auth`, `platform`, `user_agent`, `is_standalone`, `active`, `created_at`, `updated_at`, `last_used_at`
- `reg_bop`, `reg_well_head`, `reg_well_control`, `reg_fire_extinguishers`, `reg_scba`: generic helper references `id`, `reg_id`, `created_at`, `updated_at`, `inspection_status`, `rig`, plus any remaining request-body fields
- `rpc`: function namespace only, not a real table

## 2) Comparison against `029_full_app_schema.sql`

**Blocked:** `029_full_app_schema.sql` is missing from this repo.

Because the requested schema snapshot is absent, the comparison cannot be completed as requested. As a fallback, I compared the worker and frontend against `002_seed.sql` to identify likely schema-contract drift.

## 2a) Provisional table comparison against `002_seed.sql`

### Tables present in `002_seed.sql`

- `rigs`
- `contracts`
- `assets`
- `contract_assets`
- `bom_items`
- `certificates`
- `maintenance_schedules`
- `maintenance_logs`
- `transfers`
- `app_users`
- `notifications`

### Tables referenced by `_worker.js` but missing from `002_seed.sql`

- `clients`
- `delete_requests`
- `inspections`
- `projects`
- `workshops`
- `push_subscriptions`
- `reg_bop`
- `reg_well_head`
- `reg_well_control`
- `reg_fire_extinguishers`
- `reg_scba`

These may exist in the missing full schema, but they are not represented in the checked-in seed file, so the repo contract is not currently self-consistent.

## 2b) Provisional column mismatches against `002_seed.sql`

### Clear mismatches

- `contracts`: seed uses `rig`, while worker/frontend payloads use `rig_id`.
- `transfers`: worker references `supt_*` approval fields, BOM transfer fields (`bom_item_id`, `bom_item_name`, `bom_part_no`), vendor fields (`vendor_name`, `vendor_type`, `vendor_contact`), `po_number`, `return_date`, `client_id`, and `updated_at`; none of these appear in the seed insert column list.
- `app_users`: worker/frontend rely on `id`, `password`, `password_changed_at`, and `client_id`; those are not present in the seed insert column list.
- `notifications`: worker uses `id`, `user_id`, `client_id`, `event_type`, `link`, and `created_at`; seed only inserts `icon`, `kind`, `title`, `description`, `time_label`, and `is_read`.
- `rigs`: worker/frontend use `client_id`, `notes`, and `updated_at`; seed only shows `id`, `name`, `type`, `location`, `depth`, `hp`, and `status`.
- `assets`: worker reads `client_id` and `updated_at`; seed insert does not show either column.
- `certificates`: worker/frontend may carry `client_id` and `updated_at`; seed insert does not show those columns.

### Partial / likely drift

- `workshops`, `projects`, `inspections`, `clients`, `delete_requests`, `push_subscriptions`, and the `reg_*` tables cannot be validated at all because no schema declaration is present in the repo.

## 3) `index.html` create/update payload keys vs available table definitions

Because `029_full_app_schema.sql` is missing, this section compares frontend payloads to the column shapes visible in `002_seed.sql`.

### Payloads that mostly align with the available seed shape

- `assets`: `asset_id`, `name`, `category`, `status`, `rig_name`, `location`, `serial`, `notes`, `last_inspection`, `inspection_type`, `cert_link`
- `maintenance_schedules`: `asset_id`, `task`, `type`, `priority`, `freq`, `last_done`, `next_due`, `tech`, `hours`, `cost`, `status`, `alert_days`, `notes`
- `maintenance_logs` completion payload: `completion_date`, `performed_by`, `hours`, `cost`, `parts_used`, `notes` (plus API-only `next_due_override`)
- `certificates`: `cert_id`, `asset_id`, `inspection_type`, `last_inspection`, `next_inspection`, `validity_days`, `alert_days`, `cert_link`, `notes`
- `bom_items`: main editor payload matches most seed columns but omits `unit_cost`; BOM import does include `unit_cost`

### Payloads with visible mismatches or missing definitions

- `rigs`: frontend sends `client_id` and `notes`, but the seed shape does not show those columns.
- `contracts`: frontend sends `rig_id` and `notes`, but the seed shape shows `rig` and no `notes` column.
- `users`: frontend sends `password` and `client_id`, which are not represented in the seed insert column list.
- `transfers`: frontend sends BOM/vendor/PO/return fields that are not represented in the seed insert column list.
- `clients`, `projects`, `inspections`, and `workshops`: frontend payloads exist, but no schema declaration exists in this repo to validate them.

## 4) Role comparison

### Roles in `_worker.js`

Allowed app roles:

- `Admin`
- `Manager`
- `Superintendent`
- `Drilling Manager`
- `Asset Manager`
- `Maintenance Manager`
- `Project Manager`
- `Engineer`
- `Assistant`
- `Viewer`

Transfer workflow stage codes also appear in `_worker.js`, but these are **not** app roles:

- `supt`
- `drilling`
- `ops`

### Roles in `002_seed.sql`

Seeded `app_users.role` values:

- `Admin`
- `Asset Manager`
- `Viewer`
- `Editor`

### Roles in `027_rls_policies.sql`

**Blocked:** `027_rls_policies.sql` is missing from this repo.

### Role mismatches already visible

- `Editor` is seeded in `002_seed.sql` but is **not** an allowed app role in `_worker.js`.
- `_worker.js` allows several roles that have no seeded examples in `002_seed.sql`: `Manager`, `Superintendent`, `Drilling Manager`, `Maintenance Manager`, `Project Manager`, `Engineer`, `Assistant`.

## 5) Clean-inventory gate

The inventory is **not clean** yet. Blocking issues:

1. `029_full_app_schema.sql` is missing, so the requested authoritative comparison cannot be performed.
2. `027_rls_policies.sql` is missing, so role-policy alignment cannot be verified.
3. Even the fallback comparison against `002_seed.sql` shows contract drift in tables, columns, and role values.

## Recommended next steps before pushing any restored snapshot

1. Restore or add `029_full_app_schema.sql` to the repo.
2. Restore or add `027_rls_policies.sql` to the repo.
3. Re-run this audit against the actual full schema.
4. Resolve at minimum these known mismatches:
   - `contracts.rig` vs `contracts.rig_id`
   - `app_users.role = 'Editor'` vs worker allowed-role set
   - missing definitions for `clients`, `delete_requests`, `inspections`, `projects`, `workshops`, `push_subscriptions`, and `reg_*`
   - notification and transfer auxiliary columns used by the app but absent from the visible seed definition
