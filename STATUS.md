# ROSTR+ — Platform Status

Single-page snapshot of all three repos and the live deploy. Updated by hand at meaningful moments (post-audit, post-incident, post-feature-batch).

**Last updated: 2026-04-25.**

---

## At a glance

| Surface | State | Detail |
|---|---|---|
| Web — rosterplus.io | 🟢 Live | All 27 pages return 200. **Migrating Hostinger → Netlify (auto-deploy from `etchmuzik/rosterplusapp` `main`)** as of 2026-04-25; Hostinger runs in parallel as rollback. |
| iOS — App Store | 🟡 TestFlight beta | Every primary surface Supabase-backed. Build green. Awaiting first TestFlight upload via `scripts/ship.sh` |
| Supabase — `vgjmfpryobsuboukbemr` | 🟢 ACTIVE_HEALTHY | eu-west-1, Postgres 17, 17 tables (RLS enabled), 13 edge functions |
| Shared contract — this repo | 🟢 In sync | Schema regenerated 2026-04-25 |

---

## Repos

| Repo | HEAD | What's there |
|---|---|---|
| [`rosterplusapp-ios`](https://github.com/etchmuzik/rosterplusapp-ios) | `27a79c3` | iOS app. SwiftUI, Swift 6.1, iOS 18+. 97 tests passing. |
| [`rosterplusapp`](https://github.com/etchmuzik/rosterplusapp) | `32e6e75` | Web app. Static HTML/CSS/vanilla JS. 27 pages, no build step. |
| [`rosterplus-shared`](https://github.com/etchmuzik/rosterplus-shared) | `873102e` | Cross-platform contract — Supabase types + RPC catalog + schema notes |

---

## Live deploy state (rosterplus.io)

- **HTTP**: 200 on every primary page
- **Service worker on Hostinger build**: `rostr-a2d3719` (cross-origin requests pass through to respect page CSP)
- **Last Hostinger deploy**: `a2d3719 feat: site-wide footer + homepage refresh reflecting Wave 5.x` (2026-04-25 16:05 UTC) — manual `npm run deploy` from a developer's Mac
- **Commits on GitHub `main` not yet pushed to Hostinger** (this gap is what drove the Netlify migration — no auto-deploy meant manual deploy steps got missed):
  - `02ce92a fix(audit): unify availability check on RPC + housekeeping`
  - `58028a1 fix(epk): real bugs in the public EPK page + footer mislabel`
  - `61d8df1 docs: link README to rosterplus-shared contract repo`
  - `32e6e75 docs: README reflects current state`
  - `a1f51d9 docs: link to STATUS.md in shared repo`
  - `<next> feat: Netlify migration` (this commit)

### Netlify migration (in flight)

- `netlify.toml` — security headers, cache-control, 404 handler, build command
- `scripts/deploy-stamp.sh` — Netlify-callable; rotates `sw.js` `CACHE_NAME`, stamps `window.ROSTR_VERSION`, appends `?v=<sha>` to `/assets/*` refs
- `DEPLOY.md` — rewritten to document the new flow
- **Pending manual step (user)**: connect repo at [app.netlify.com](https://app.netlify.com), point `rosterplus.io` DNS at Netlify load balancer
- **Hostinger stays parallel** for ~1 week as a hot rollback. Cancel after Netlify proves stable.

---

## Cross-platform parity

The 2026-04-25 audit drove the most recent batch of work. Status of the P1 findings:

| Finding | Status | Where |
|---|---|---|
| iOS payments missing `generate_invoice_number` | ✅ Not applicable — iOS doesn't write payments, only reads them | (audit was wrong) |
| iOS signup missing `claim_artist_profile` | ✅ Not applicable — that RPC is the *manual claim* flow, not signup. Both sides correctly don't call it on signup | (audit was wrong) |
| iOS `ReviewView` had no Supabase backing | ✅ **Fixed** — `Stores/ReviewStore.swift` calls `create_review` RPC | iOS `336fc94` |
| Web availability check used inline JS instead of RPC | ✅ **Fixed** — `DB.checkAvailability` now calls the same RPC iOS uses, with inline fallback | Web `02ce92a` |
| iOS never wrote `profiles.onboarding_complete` | ✅ **Fixed** — `ProfileStore.markOnboardingComplete` called from `ProfileEditView` save | iOS `336fc94` |
| EPK page broken (no `_epkData`, footer bounced promoters to login, lost inquiries on email failure) | ✅ **Fixed** — committed but waiting on Hostinger deploy | Web `58028a1` |
| Web SW broke site CSP | ✅ **Fixed and deployed** | Web `2521872` |

---

## Live Supabase resources

### Tables (17, all RLS-enabled)
artists, bookings, booking_events, contracts, payments, profiles, messages, notifications, reviews, invitations, venues, device_tokens, email_events, client_errors, cron_runs, admin_audit_log, admin_rate_counter

### Edge functions (13 active)
signup, send-password-reset, send-email, send-booking-reminders, send-artist-onboarding-drip, send-review-prompts, admin-daily-digest, admin-user-action, send-push, profile-share, stripe-webhook, resend-webhook, health

### RPCs called by clients
- **Both clients**: `check_availability`, `create_review`
- **Web only**: `generate_invoice_number`, `review_stats_for_user`, `reviews_for_user`, `claim_artist_profile`, plus 11 admin RPCs (admin tooling is web-only by design)
- **iOS only**: *(none)*

Full caller list: [`RPC_CONTRACT.md`](./RPC_CONTRACT.md).

---

## Cron health

8 scheduled jobs, all self-logging to `public.cron_runs` and visible at [rosterplus.io/status.html](https://rosterplus.io/status.html):

- `send-booking-reminders` — hourly (24h before event)
- `send-artist-onboarding-drip` — hourly (1h/24h/72h artist drip)
- `send-review-prompts` — daily (3 days post-event)
- `admin-daily-digest` — daily 05:00 UTC
- `expire-stale-contracts` — daily 02:00 UTC
- `prune-client-errors` — daily 03:00 UTC (drops > 30 days)
- `prune-email-events` — daily 03:30 UTC (drops > 90 days)
- `prune-cron-runs` — weekly Sunday 04:00 UTC (drops > 90 days)

---

## Outstanding follow-ups (not P0)

From the 2026-04-25 audit:

- **Web inline-style cleanup** — `dashboard.html` has 39 `style=` attributes. Extract utility classes. ~2 hours.
- **Web aria-label sweep** — `contracts.html` 4/15 buttons labeled, `dashboard.html` 2/5. Action surfaces firing money/legal events should all be labeled.
- **Reviews UI on iOS public-profile screens** — `review_stats_for_user` and `reviews_for_user` RPCs exist on the server but iOS doesn't yet display reviews. Currently a write-only feature on iOS.
- **Supabase advisor**: `admin_rate_counter` has RLS enabled but no policies. Likely intentional; one-line confirming comment.
- **Supabase advisor**: leaked-password protection (HaveIBeenPwned) is disabled. Should be enabled given the platform handles money.

---

## How this file gets updated

Hand-maintained. Update at:

- After a meaningful release (multiple PRs landing in a batch).
- After resolving an incident.
- After a quarterly audit pass.

The shared repo's `RPC_CONTRACT.md` is the source of truth for which client calls what — this file is the higher-level snapshot pointing back to it.
