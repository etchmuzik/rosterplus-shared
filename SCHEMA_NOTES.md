# Schema notes

Generated types in [`types/supabase.ts`](./types/supabase.ts) capture
column shapes. They don't capture semantic conventions. This document
does.

---

## Soft-delete

Tables with a `deleted_at` column use soft-delete. **Always filter
`deleted_at IS NULL` in client queries** unless you specifically want
deleted rows.

- `profiles.deleted_at`
- `artists.deleted_at`
- `bookings.deleted_at`

Web pattern: `_sb.from('artists').select(...).is('deleted_at', null)`.

iOS pattern: `client.from("artists").select(...).is("deleted_at", value: nil)`.

---

## Status enums

These columns are `text` in the schema but only take a fixed set of
values. The DB doesn't enforce — the app code does.

### `bookings.status`
DB CHECK constraint `bookings_status_check` enforces:
- `inquiry` — first contact, promoter exploring availability
- `pending` — formal request sent, artist hasn't responded
- `confirmed` — accepted, no contract yet
- `contracted` — contract drafted/signed
- `completed` — event date passed (set by cron)
- `cancelled` — explicit cancel (covers former "rejected" copy)

Availability checks (`check_availability` RPC and inline JS fallback)
treat `confirmed`, `contracted`, `pending` as occupying the date.
`inquiry` does NOT occupy the date.

### `contracts.status`
- `draft`
- `awaiting_signatures` — at least one party hasn't signed
- `signed` — both signed
- `expired` — past `expires_at`, no signatures (cron flips this via
  `expire_stale_contracts`)
- `cancelled`

### `payments.status`
DB CHECK constraint `payments_status_check` enforces:
- `pending`
- `processing` — promoter recorded payout, waiting for artist confirm
- `completed` — both sides confirmed, `paid_at` set
- `failed`
- `refunded`

Note: iOS `PaymentRow.Status` maps `completed → .paid` for display copy
(`PaymentsStore.swift:121`). The wire value is `completed`.

### `payments.type`
DB CHECK constraint `payments_type_check` enforces:
- `deposit`
- `milestone`
- `final`
- `refund`

### `invitations.status`
- `pending`
- `accepted`
- `revoked`

### `notifications.type`
Loose categorization (no enforcement). Used to pick an icon and route
href client-side. Common values: `booking_request`, `booking_accepted`,
`contract_signed`, `payment_received`, `message`, `review_received`.

### `device_tokens.platform`
- `ios` — APNs production token
- `ios_dev` — APNs sandbox token (dev builds)
- `web` — Web Push subscription endpoint

### `device_tokens.environment`
- `production`
- `sandbox`

### `profiles.role`
- `promoter` (default)
- `artist`
- `admin` (set manually via `admin_update_user_role` RPC)

The signup edge function rejects any role outside `promoter` /
`artist` — admin role is admin-promoted only.

---

## `artists.genre` vs `artists.subgenres` — column merge (2026-05-17)

Both columns are `text[]`. **The web client merged them into a single
picker on 2026-05-17** — every artist pick now lands in
`artists.genre`, and `artists.subgenres` is set to `[]` on every
save. The column was not dropped; reading code should still tolerate
non-empty `subgenres` until the next backfill cycle eliminates it.

### Read pattern (web)
The DB layer (`web/assets/js/app.js`) ships a helper
`_mergedGenreList(row)` that returns the deduped union of
`row.genre` + `row.subgenres` as `string[]`. `getArtists`,
`getArtistById`, and `getMyArtistProfile` all expose this as
`genres: string[]` alongside the legacy single-string `genre`. New
display code should consume `data.genres` and join with `' · '`;
single-label slots (compact cards, OG meta) may use `genres[0]`.

### Canonical genre catalogue
The 12 valid primary genres are listed in `window.GENRES` at the top
of `assets/js/app.js`. Each carries a `subs: string[]` of valid
subgenres. The artist picker (`artist-profile-edit.html`) and the
directory filter (`directory.html`) both read from this catalogue —
**do not hardcode genre lists in other surfaces**.

### iOS parity
iOS reads `artist.genre` directly (text[]). The merge is transparent
to iOS because every artist's full set lives in that one column
post-merge. iOS does not read or write `subgenres`.

### History
- Pre-2026-05-17: artists picked ONE primary from a dropdown +
  free-text subgenres. Two columns, inconsistent picker lists, and
  a primary/sub distinction with no real semantic meaning.
- 2026-05-17: web unified pickers and column writes. Backfill on
  2026-05-17 normalized one stale row (`Progressive` → `Progressive House`).

---

## Realtime channels

Tables with realtime enabled (clients can subscribe to live changes):

- `messages` — both clients use this for inbox/thread updates.
- `booking_events` — both clients use this for the booking-detail
  timeline.
- `notifications` — used for the unread-badge and toast surfaces.

Subscribe pattern (web): `_sb.channel(...).on('postgres_changes', ...)`.
Subscribe pattern (iOS): `RealtimeV2.channel(...).on(...)`.

---

## RLS

Every public table has RLS enabled. Policies are defined in the
Supabase project — clients should never assume "the user can see this
row" — always go through RLS.

Helper functions used in policies:
- `is_admin()` — true if `current_user.role = 'admin'`
- `_artist_user_id(artist_id)` — returns the `profile_id` claimant
- `_current_email()` — current `auth.email()`

One known advisory: `admin_rate_counter` has RLS enabled but no
policies. Likely intentional (table is internal) — confirm before
adding policies.

---

## Triggers worth knowing about

- `handle_new_user` (on `auth.users` INSERT) — creates the matching
  `public.profiles` row. **This is why the signup edge function is
  thin** — the trigger does the heavy lifting.
- `notify_booking_event` (on `bookings` UPDATE) — writes to
  `booking_events` so timelines reflect status changes.
- `notify_message_event`, `notify_contract_event`,
  `notify_payment_event` — same pattern, write to `notifications`.
- `notify_push_on_notification` (on `notifications` INSERT) — fan-out
  to `device_tokens` via the `send-push` edge function.
- `prevent_role_change` (on `profiles` UPDATE) — blocks any update
  that would change `role` from a non-admin context.

---

## Foreign-key shapes worth memorizing

- `artists.profile_id → profiles.id` — nullable. NULL means the
  artist row is **unclaimed** (admin-pre-created). Web's claim flow
  uses the `claim_artist_profile` RPC to set this.
- `bookings.promoter_id → profiles.id`
- `bookings.artist_id → artists.id`
- `bookings.venue_id → venues.id` — nullable. The web booking form
  also accepts free-text `venue_name` for ad-hoc venues.
- `contracts.booking_id → bookings.id`
- `payments.booking_id → bookings.id`
- `messages.{sender_id, receiver_id} → profiles.id`
- `messages.booking_id → bookings.id` — nullable. Threads are
  booking-scoped; null means a direct message outside any booking
  (rare).
- `booking_events.booking_id → bookings.id`
- `reviews.booking_id → bookings.id`
- `reviews.{reviewer_id, target_id} → profiles.id` (target is the
  user being rated, not their `artists.id`).
