# RPC Contract

This document is the authoritative list of which client calls which RPC
or edge function. Last reviewed: **2026-04-25**.

Update this file when adding or removing a server-side function. Drift
between iOS and web at the data layer was the root cause of the
2026-04-25 audit's P1 findings — keeping this catalog accurate is the
single most effective check against that drift.

The generated TypeScript types in [`types/supabase.ts`](./types/supabase.ts)
already capture argument and return shapes. This file captures the
**caller side** — semantic context the types can't express.

---

## RPCs

### `check_availability(p_artist_id uuid, p_event_date date)`
Returns `{ available: bool, reason: text }[]` (always one row).

- **iOS**: `Stores/AvailabilityCheckStore.swift` — `BookingView` calls
  this whenever artist or date changes.
- **Web**: `assets/js/app.js` `DB.checkAvailability` — preferred path,
  with an inline `bookings` overlap query as fallback if the RPC errors.
- **Notes**: this is the canonical "is this artist free on this date"
  source. As of 2026-04-25, both clients route through the RPC — the
  audit migrated web from inline-only to RPC-with-fallback.

### `create_review(p_booking_id uuid, p_rating int, p_comment text)`
Returns the new `reviews.id` as a uuid.

- **iOS**: `Stores/ReviewStore.swift` — `ReviewView` Submit CTA
  (added 2026-04-25).
- **Web**: `assets/js/app.js` `DB.createReview` — booking-detail
  modal's review form.
- **Notes**: server-side enforces caller participated in the booking,
  rating in `[1, 5]`, one review per `(booking, reviewer)`. Tag chips
  on iOS are joined into the comment as a leading hashtag block to
  match the web wire format.

### `review_stats_for_user(p_user_id uuid)`
Returns `{ avg_rating, review_count }`.

- **iOS**: not yet wired (no public-profile-stats screen).
- **Web**: `assets/js/app.js` `DB.getReviewStats` — artist profile
  rating badge.

### `reviews_for_user(p_user_id uuid, p_limit int)`
Returns recent reviews.

- **iOS**: not yet wired.
- **Web**: `assets/js/app.js` `DB.getReviewsForUser` — artist profile
  reviews list.

### `claim_artist_profile(target_artist_id uuid)`
Returns the claimed `artists` row. SECURITY DEFINER.

- **iOS**: not used. iOS `Features/Claim/ClaimView.swift` is a
  different feature — a 3-step verification checklist (email, social,
  payout), not "claim this pre-existing artist row by id".
- **Web**: `assets/js/app.js` `DB.claimArtistProfile` — manual claim
  flow on `claim-profile.html`. Lets a freshly-signed-up artist take
  ownership of an admin-pre-created `artists` row.
- **Notes**: signup paths on both clients do **not** call this — the
  `handle_new_user` trigger creates the matching `profiles` row, but
  `artists` rows are created separately (admin or manual claim).

### `generate_invoice_number()`
Returns the next sequential invoice number as text.

- **iOS**: not used. iOS reads `payments` rows but doesn't write them
  (payment-create is a web-only surface today).
- **Web**: `assets/js/app.js` `DB.generateInvoice` — called before
  inserting into `payments` so receipts have a canonical sequence.

### `cron_health_public()` / `cron_health_summary()` / `cron_history_7d(p_job)`
Cron job status reporting.

- **iOS**: not used.
- **Web**: `assets/js/app.js` — surfaced on `status.html`.

### Admin RPCs (web-only)
`admin_stats`, `admin_list_users`, `admin_update_user_role`,
`admin_force_cancel_booking`, `admin_undo_last_action`,
`admin_email_stats`, `admin_broadcast_notification`,
`log_admin_action`, `log_impersonation_event`, `is_admin`.

- **iOS**: not used. Admin tooling is intentionally web-only — phones
  aren't the right surface for a moderation console.
- **Web**: `assets/js/app.js` admin code path, exposed on `admin.html`.

### Internal / triggers (do NOT call from clients)
`_admin_rl_hit`, `_admin_rl_hit_for`, `_artist_user_id`, `_current_email`,
`current_role`, `expire_stale_contracts`, `prevent_role_change`,
`rls_auto_enable`, `handle_new_user`, `audit_artist_change`,
`audit_artist_insert`, `notify_booking_event`, `notify_contract_event`,
`notify_message_event`, `notify_payment_event`,
`notify_push_on_notification`, `log_cron_run`,
`log_booking_status_change`.

These run from triggers, RLS policies, or pg_cron jobs. Client code
should not invoke them directly.

---

## Edge functions

### `signup`
- **iOS**: `Stores/AuthStore.swift` `signUp()`.
- **Web**: `assets/js/app.js` `Auth.signUp()`.
- **Why**: bypasses Supabase's built-in SMTP (which would need
  dashboard config + gets rate-limited). Uses the admin API to create
  the user with `email_confirm=true` so they can sign in immediately.
  Fires the `handle_new_user` trigger to create the matching
  `profiles` row. Sends the welcome email via Resend.
- **Returns**: 200 on success; non-2xx body carries machine codes
  (`email_taken`, `weak_password`, `invalid_email`, `invalid_role`,
  `rate_limited`).

### `send-password-reset`
- **iOS**: `Stores/AuthStore.swift` `forgotPassword()`.
- **Web**: `assets/js/app.js` `Auth.sendPasswordReset()`.
- **Notes**: always returns 200 (account-enumeration defence). UI on
  both clients shows a generic "check your email" confirmation
  regardless of whether the account actually exists.

### `send-email`
- **iOS**: `Stores/InvitationsStore.swift`.
- **Web**: `assets/js/app.js` `Emails.send` — booking_request,
  booking_confirmation, booking_accepted, booking_rejected,
  contract_signed, payment_received, payment_recorded, invitation,
  EPK inquiry.
- **Notes**: dispatches to Resend. Body shape is
  `{ to, type, data }` — `type` switches the template.

### `admin-user-action`
- **iOS**: not used.
- **Web**: admin console actions (impersonate, force-action).

### Cron-only / no client caller
`admin-daily-digest`, `send-booking-reminders`, `send-review-prompts`,
`send-artist-onboarding-drip`, `profile-share`, `send-push`,
`stripe-webhook`, `resend-webhook`, `health`.

These are invoked by pg_cron schedules or external webhooks. Client
code does not call them directly.

---

## How to update this file

1. **Schema change** (new RPC, removed RPC, signature change):
   - Run `./scripts/regenerate-types.sh` to refresh
     `types/supabase.ts`.
   - Update the matching section in this file: caller list, notes,
     and any cross-client semantics.
   - Bump the "Last reviewed" date at the top.

2. **New caller** (a previously-unused RPC starts being called by a
   client):
   - Update the **iOS** or **Web** bullet in that RPC's section.
   - Note the call site (`Sources/...` or `assets/js/app.js`).

3. **Removed caller** (a client stops using an RPC):
   - Either delete the bullet, or note it as "not used (was X, removed
     YYYY-MM-DD)".

4. **Audit cadence**: re-read top to bottom every quarter or after
   any major release. The audit harness in
   [`AUDIT-2026-04-25.md`](https://github.com/etchmuzik/rosterplus-shared/blob/main/AUDIT-2026-04-25.md)
   *(if you copy that file in)* mechanically diffs `.from( / .rpc( /
   .functions.invoke(` calls between the two clients and the live
   schema — run that as the spot-check.
