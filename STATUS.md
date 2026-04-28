# ROSTR+ — Platform Status

Single-page snapshot of all three repos and the live deploy. Updated by hand at meaningful moments (post-audit, post-incident, post-feature-batch).

**Last updated: 2026-04-28 (go-live audit).**

---

## At a glance

| Surface | State | Detail |
|---|---|---|
| Web — rosterplus.io | 🟢 Live | All 27 pages return 200. **Migrating Hostinger → Netlify (auto-deploy from `etchmuzik/rosterplusapp` `main`)** as of 2026-04-25; Hostinger runs in parallel as rollback. |
| iOS — App Store | 🟡 TestFlight beta | Every primary surface Supabase-backed. Build green, **108 tests** passing. Push-tap deep-links + universal links wired (apple-app-site-association still pending server-side). Money is `Decimal` end-to-end. AR localisation foundation shipped (24 high-traffic strings). |
| Supabase — `vgjmfpryobsuboukbemr` | 🟢 ACTIVE_HEALTHY | eu-west-1, Postgres 17, 17 tables (RLS enabled), 13 edge functions |
| Shared contract — this repo | 🟢 In sync | Schema regenerated 2026-04-25 |

---

## Repos

| Repo | HEAD | What's there |
|---|---|---|
| [`rosterplusapp-ios`](https://github.com/etchmuzik/rosterplusapp-ios) | `b542481` | iOS app. SwiftUI, Swift 6.1, iOS 18 deployment target. 108 tests passing. |
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

## What landed in the 2026-04-27 afternoon batch

- **iOS — Inject-able `ProfileWriter`.** ProfileStore writes go through a tiny protocol with a Supabase default; tests inject mocks. Three optimistic-update tests that were disabled with `.disabled("Needs injectable client …")` are now green plus a new `rollbackOnFailure` case.
- **iOS — Localisation foundation.** `Sources/Resources/Localizable.xcstrings` ships EN + AR translations for 24 high-traffic keys (common verbs, tab labels, auth flows, primary CTAs, state copy, screen titles). `S.Common.back` / `S.Tab.home` / `S.State.offline` style accessors so views can't fat-finger keys. NavHeader + OfflineBanner already pull from the catalog; the rest of the views still use literal strings — incremental sweep from here.
- **Supabase — `admin_rate_counter` documented.** Migration `document_admin_rate_counter_intentional_no_policies` adds a `COMMENT ON TABLE` explaining that RLS-enabled-with-zero-policies is the intended state (only `_admin_rl_hit` SECURITY DEFINER touches it). The advisor still flags it as an INFO; that's now a known-and-intended.
- **Supabase — Leaked-password protection.** Still pending — that's a dashboard toggle (Auth → Settings → Password Strength → enable HaveIBeenPwned check), not a SQL change. Flip it next time you're in the dashboard.
- **Web — dashboard utility classes.** `dashboard.html` from 38 inline `style=` attributes to 20. Adds generic utilities to `system.css` (`.label-mono`, `.flex-row`, `.text-status-confirmed`, etc.). Remaining 20 are multi-property compounds + JS-template interpolations.
- **Web — contracts modal aria-labels.** Modal close buttons now say *"Close contract preview"* / *"Close new-contract form"* instead of the generic *"Close dialog"*.

## What landed in the 2026-04-27 morning batch

Driven by the full A-to-Z audit at `workspace/docs/IOS-FULL-AUDIT-2026-04-27.md`:

- **CalendarView back button** — was missing entirely; users entering Calendar from the artist dashboard had no way back. Fixed via `NavHeader`.
- **Sign-out clears every user-scoped store** — Bookings, Inbox, Notifications, Payments, Profile, ArtistDetail, Timeline, Invitations, Contracts, Roster — so user B doesn't briefly see user A's data on shared devices. Realtime channels unsubscribed in the same flow.
- **Push-notification taps deep-link** to the right `Route` via APNs payload `href` parsing. Foreground banners now surface (the OS used to swallow them when the app was open).
- **Universal links + custom-scheme** (`https://rosterplus.io/...`, `rostr://...`) routed via a single `Route.parse(href:)` shared with notification taps. **Server-side `apple-app-site-association` still pending** — the iOS code is ready but URLs won't deep-link until the file's published.
- **Pull-to-refresh** on every list (Bookings, Inbox, Notifications, Payments, Home, ArtistDashboard).
- **scenePhase listener** — backgrounding for an hour and returning re-fetches stale data automatically.
- **Offline banner** — `NWPathMonitor` with 1.5 s debounce, slides in from the top.
- **Money → `Decimal` end-to-end** on `PaymentDTO.amount`, `BookingDTO.fee`, `ArtistDTO.baseFee`. Single `MoneyFormatter` for "AED 28K" / "AED 28,500" rendering.
- **EPK share sheet** — was a no-op stub for waves; now wired to `UIActivityViewController` with the public web URL.
- **Ratings dropped from artist + EPK + roster cards** per product. Reviews flow (post-event prompt, ReviewView, `create_review` RPC) is intact — we just don't show aggregate scores on profiles.
- **`Route: CaseIterable + Sendable`** plus a `NavigationBackAffordanceTests` suite that walks every detail Route and asserts the matching view source contains `nav.pop()`. Guards the CalendarView regression-class going forward.
- **iOS 18 deployment target**, `os.Logger` instead of `print()` (11 sites), `URL!` force-unwrap removed, `R.C.fg3` raised 0.38 → 0.48 to clear WCAG AA, decorative icons marked `accessibilityHidden`.

## What landed in the 2026-04-28 go-live audit batch

Driven by the full pre-launch audit at `~/.claude/plans/full-audit-we-going-zippy-finch.md`:

- **🔴 8 missing edge functions repatriated to git.** Pre-audit, only 5 of the 13 deployed edge functions lived in source control (`send-artist-onboarding-drip`, `send-booking-reminders`, `send-email`, `send-review-prompts`, `signup`). The other 8 — `admin-daily-digest`, `admin-user-action`, `health`, `profile-share`, `resend-webhook`, `send-password-reset`, `send-push`, `stripe-webhook` — were deployed but un-versioned, so a Supabase outage could have wiped them with no recovery path. Pulled all 8 into `web/supabase/functions/` via MCP and committed.
- **🔴 iOS sign-out cross-user leak fixed.** AppRoot now resets `availabilityCheck`, `analytics`, and `push` stores on `signedOut` (previously only 10 of 13 stores). `PushStore.clearToken(for:)` is called with the previous user's UUID so the device-tokens row is removed — user B signing in on the same device no longer inherits user A's APNs registration. Added `reset()` methods to PushStore + AvailabilityCheckStore + AnalyticsStore. **108 tests still passing.**
- **🔴 Apple App Site Association file added.** `web/.well-known/apple-app-site-association` ships with the right components map (bookings, threads, contracts, invoices, reviews, artists, epks, notifications), webcredentials, and `Content-Type: application/json` enforced via `netlify.toml`. **Operator must replace `__TEAMID__` placeholder with the real Apple Team ID before universal links resolve** — that's a one-line edit + commit, not in this batch because the team ID isn't in the repo.
- **🟠 CSP `worker-src 'self'` added** to the Netlify CSP header — strict CSP validators stop flagging the SW registration.
- **🟠 `shared/types/supabase.ts` regenerated** from the live schema (2026-04-28).
- **STATUS.md correction:** `UIBackgroundModes = remote-notification` was already set in `ios/Config/Shared.xcconfig` before this audit. Previous STATUS listed it as pending — that was wrong.

## Outstanding follow-ups (not P0)

From the 2026-04-25 + 2026-04-27 + 2026-04-28 audits:

- **Apple Team ID for AASA** — `web/.well-known/apple-app-site-association` ships with `__TEAMID__` placeholder. Replace with the real ID before universal links go live.
- **Supabase leaked-password protection (HaveIBeenPwned) is disabled.** Dashboard toggle at Auth → Settings → Password Strength. Required for launch given the platform handles money.
- **Supabase advisor — 35 SECURITY DEFINER functions are anon-executable.** New finding from 2026-04-28 audit. Most are intentional (rate limiters need to be callable; admin RPCs internally check `is_admin()`). The 13 trigger-class functions (`audit_*`, `notify_*`, `log_*`, `handle_new_user`, `rls_auto_enable`) probably shouldn't be REST-exposed at all — they're invoked by triggers, not clients. Safe to defer (they no-op when called out of trigger context) but worth a `REVOKE EXECUTE ... FROM anon, authenticated` sweep.
- **Web inline-style cleanup** — `web/admin.html` has 222 `style=` attributes (worst offender). Dashboard, artist-dashboard, settings, messages, profile, payments all 28+. Extract to `system.css` utility classes.
- **Web aria-label sweep** — `contracts.html` 4/15 buttons labeled, `dashboard.html` 2/5. Action surfaces firing money/legal events should all be labeled.
- **Reviews UI on iOS public-profile screens** — `review_stats_for_user` and `reviews_for_user` RPCs exist on the server but iOS doesn't yet display reviews. Write-only on iOS by current product call.
- **Localization sweep** — foundation is in place (24 keys + EN/AR + type-safe accessors). 152 literal `Text("...")` strings remain across iOS views. Incremental sweep, no big-bang.
- **Supabase advisor**: `admin_rate_counter` has RLS enabled but no policies. Documented as intentional via `COMMENT ON TABLE`; advisor still flags as INFO.

---

## How this file gets updated

Hand-maintained. Update at:

- After a meaningful release (multiple PRs landing in a batch).
- After resolving an incident.
- After a quarterly audit pass.

The shared repo's `RPC_CONTRACT.md` is the source of truth for which client calls what — this file is the higher-level snapshot pointing back to it.
