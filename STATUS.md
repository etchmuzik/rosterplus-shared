# ROSTR+ — Platform Status

Single-page snapshot of all three repos and the live deploy. Updated by hand at meaningful moments (post-audit, post-incident, post-feature-batch).

**Last updated: 2026-05-12 PM (post-polish-batch — roster faces on homepage, /a/<handle>, /link, /press, operator-set featured, click tracking, handle slugs).**

> See [`workspace/docs/AUDIT-2026-05-12-LAUNCH.md`](../workspace/docs/AUDIT-2026-05-12-LAUNCH.md)
> for the full pre-launch verification (web smoke, backend health,
> security headers, SEO, cron, advisors, error patterns).

---

## At a glance

| Surface | State | Detail |
|---|---|---|
| Web — rosterplus.io | 🟢 **Launch-ready** | All 28 pages return 200 (added `/press.html` + `/link.html`). Live SHA `e6bb6ef` matches origin matches local. SW cache + `window.ROSTR_VERSION` stamped each push. HSTS/CSP/HTTP3 healthy. 0 client_errors in last 24h. Privacy policy revised for App Store sub-processor disclosure. **Homepage now uses real roster faces** (avatar_url → `/assets/images/artists/<handle>.jpg` → initials). Per-artist Linktree live at `/a/<handle>`. Operator-set "Artist of the week" via `featured_until`. Plausible click tracking on `/link` + `/a/*` CTAs. |
| iOS — App Store | 🟡 TestFlight beta | Every primary surface Supabase-backed. Build green, **108 tests** passing. Build 4 on TestFlight 2026-05-11 with the `UIBackgroundModes` fix — silent push now works. AASA live at `/.well-known/apple-app-site-association`; universal links into the app dispatch for 9 path patterns. `ITSAppUsesNonExemptEncryption=false` baked into Info.plist so ASC never prompts. App Store metadata draft at `workspace/docs/APP_STORE_METADATA.md`. Money is `Decimal` end-to-end. AR localisation foundation shipped (24 high-traffic strings, sweep ongoing). |
| Supabase — `vgjmfpryobsuboukbemr` | 🟢 ACTIVE_HEALTHY | eu-west-1, Postgres 17, 17 tables (RLS enabled), 13 edge functions. 11 active verified artists on roster. **Zero errors in 365+ cron invocations over last 7 days.** |
| Shared contract — this repo | 🟢 In sync | Schema regenerated 2026-04-28. No new RPCs / edge functions in polish batch — `handle` + `featured_until` are direct PostgREST writes against `artists`. |

---

## Repos

| Repo | HEAD | What's there |
|---|---|---|
| [`rosterplusapp-ios`](https://github.com/etchmuzik/rosterplusapp-ios) | `c787d5f` | iOS app. SwiftUI, Swift 6.1, iOS 18 deployment target. 108 tests passing. Build 4 on TestFlight. |
| [`rosterplusapp`](https://github.com/etchmuzik/rosterplusapp) | `e6bb6ef` | Web app. Static HTML/CSS/vanilla JS. **28 pages**, no build step. **Launch-ready, polish batch shipped 2026-05-12.** |
| [`rosterplus-shared`](https://github.com/etchmuzik/rosterplus-shared) | `fb8910a` | Cross-platform contract — Supabase types + RPC catalog + schema notes |

---

## Live deploy state (rosterplus.io)

- **HTTP**: 200 on every public page (verified 2026-05-12 across all 28 HTML routes — `/press.html` and `/link.html` added in polish batch)
- **Live build SHA**: `e6bb6ef` (matches `origin/main` and local `HEAD`).
- **Last deploy**: `e6bb6ef chore(homepage): drop static placeholders/* srcs from featured + gallery` (2026-05-12 PM). Markup now ships neutral (initials-only tiles, src-less featured `<img>`); JS hydration is the single source of truth, setting srcs from `artistPhotoSrc()` once `DB.getArtists` resolves.
- **Security headers**: CSP locked to 3 known origins, HSTS preloaded 1y, X-Frame-Options DENY, Permissions-Policy denies camera/microphone/geolocation. HTTP/3 (alt-svc).
- **Backend (Supabase) health**: ACTIVE_HEALTHY. 365+ cron invocations in 7 days, **zero errors**. 0 client_errors in last 24h. Edge function `/health` returns 200. Anon REST `artists?select=count` returns 200.
- **Deploy pipeline**: `npm run ship` (push+deploy) plus pre-push git hook means every push from this machine is auto-deployed. Deploy gap that caused the 2026-04-30 EPK incident is closed.

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
| EPK page broken (no `_epkData`, footer bounced promoters to login, lost inquiries on email failure) | ✅ **Fixed and deployed** 2026-04-30 | Web `58028a1` |
| EPK ignored `?id=` param so every share link bounced to /directory | ✅ **Fixed and deployed** 2026-04-30 | Web `ecc1e83` |
| EPK duplicate `const` killed the inline script, page stuck on "Loading…" | ✅ **Fixed and deployed** 2026-04-30 | Web `b8cc8fc` |
| `deploy.sh --skip-checks` flag rejected before reaching the parser; orphan reviews-tests blocked deploys | ✅ **Fixed** | Web `1864df9` |
| Web SW broke site CSP | ✅ **Fixed and deployed** | Web `2521872` |

---

## Live Supabase resources

### Tables (17, all RLS-enabled)
artists, bookings, booking_events, contracts, payments, profiles, messages, notifications, reviews, invitations, venues, device_tokens, email_events, client_errors, cron_runs, admin_audit_log, admin_rate_counter

**Recent additions to `artists`** (2026-05-12):
- `handle` (`text`, partial-unique on `LOWER(handle) WHERE profile_id IS NULL AND deleted_at IS NULL`) — kebab-case slug powering `/a/<handle>` per-artist Linktree pages. CHECK constraint `[a-z0-9](?:[a-z0-9-]{1,30}[a-z0-9])?`. Migration `20260512_artists_handle.sql` backfilled all existing rows from `stage_name` with `-2`/`-3` disambiguation.
- `featured_until` (`timestamptz`) — operator-set "Artist of the week" expiry. Set via admin UI on `/admin.html`; consumed by `/link.html` (overrides ISO-week fallback) and `/index.html` (featured card pick). Migration `20260512_artists_featured_until.sql`. Partial index on `(featured_until DESC) WHERE featured_until IS NOT NULL AND deleted_at IS NULL` (can't put `now()` in predicate — must be IMMUTABLE).

### Edge functions (13 active)
signup, send-password-reset, send-email, send-booking-reminders, send-artist-onboarding-drip, send-review-prompts, admin-daily-digest, admin-user-action, send-push, profile-share, stripe-webhook, resend-webhook, health

### RPCs called by clients
- **Both clients**: `check_availability`
- **Web only**: `generate_invoice_number`, `claim_artist_profile`, plus 11 admin RPCs (admin tooling is web-only by design)
- **iOS only**: *(none)*
- **Dormant** (server-side intact, no client caller): `create_review`, `review_stats_for_user`, `reviews_for_user` — reviews UI removed from both clients on 2026-04-29.

Full caller list: [`RPC_CONTRACT.md`](./RPC_CONTRACT.md).

---

## Cron health

8 scheduled jobs, all self-logging to `public.cron_runs` and visible at [rosterplus.io/status.html](https://rosterplus.io/status.html):

- `send-booking-reminders` — hourly (24h before event)
- `send-artist-onboarding-drip` — hourly (1h/24h/72h artist drip)
- `send-review-prompts` — **PAUSED 2026-04-29** (reviews UI removed from both clients; cron job kept disabled, edge function preserved)
- `admin-daily-digest` — daily 05:00 UTC
- `expire-stale-contracts` — daily 02:00 UTC
- `prune-client-errors` — daily 03:00 UTC (drops > 30 days)
- `prune-email-events` — daily 03:30 UTC (drops > 90 days)
- `prune-cron-runs` — weekly Sunday 04:00 UTC (drops > 90 days)

---

## What landed in the 2026-05-12 polish batch

Driven by the punch list at `~/.claude/plans/now-make-your-final-swift-sunrise.md`. Five items closed:

- **#10 — Handle-edit UI on `artist-profile-edit.html`.** Artists can now change their `/a/<handle>` slug. Share-link card grew an editable handle input with a static `https://rosterplus.io/a/` prefix label, format validation against `^[a-z0-9](?:[a-z0-9-]{1,30}[a-z0-9])?$`, uniqueness check, and a reserved-word denylist (`a`, `admin`, `api`, `link`, `press`, etc.) so artists can't claim a route that collides with the app. `DB.updateArtistProfile` allowlist extended to accept `handle`.
- **#11 — Operator-set featured artist.** New `featured_until TIMESTAMPTZ` column on `artists`. Admin UI on `/admin.html` shows a "Feature 24h / 7d / 30d" trio per artist row, switching to "★ Unfeature (Xd left)" once active. `DB.adminSetFeatured(artistId, untilIso)` and `DB.getCurrentlyFeatured()` added. `/link.html` two-stage resolution: operator-set wins, ISO-week rotation is the fallback so the homepage never has an empty featured card. `/index.html` featured-card pick prefers any currently-featured artist.
- **#12 — Plausible click tracking.** Tiny `trackLink(eventName)` / `trackArtistCta(eventName, handle)` helpers added to `/link.html` and `/a.html` — explicit `window.plausible(...)` calls, no DOM-attribute approach (matches the existing `app.js:710` pattern). 8 CTAs on `/link.html` (4 buttons + 4 social icons) and 7 CTAs on `/a.html` (3 buttons + per-channel social) now report. Artist handle passed as a Plausible prop so reports break down per artist.
- **#14 — `/press.html` stub.** Honest empty state ("Nothing to show — yet"); mailto CTA to `hi@rosterplus.io` for journalists; sitemap entry at priority 0.4; homepage feature card 07/TRUST got the "Press coverage →" link back.
- **#15 — Directory count strip.** `/directory.html` now shows "11 verified artists · 8 cities" above the grid (computed from filtered view, so the count drops as you filter by city). `.dir-stats-strip` added to `system.css`.

**Plus the roster-on-homepage finish (2026-05-12 PM):**
- Shared `artistPhotoSrc(a)` helper with three-tier chain: `profiles.avatar_url` → `/assets/images/artists/<handle>.jpg` → initials. Used by both the featured-card avatar AND the hero background, AND every gallery tile. Removed all six static `placeholders/gallery-N.jpg` references and the static `placeholders/hero-featured.jpg` / `featured-avatar.jpg` srcs — markup ships neutral, JS upgrades on hydration.
- `DB.getArtists` + `getArtistById` now surface `handle`, `stage_name`, `featured_until` on the normalised objects.

Photo coverage today: 9 of 11 active artists have a portrait on disk (`ashkan-k, borey, epi, etch, highlite, imen, katrin-losa, lith-k, sarabi`). The two without (`anturage, eva-kim`) gracefully fall through to initials.

## What landed in the 2026-05-12 launch-audit batch

(Items from the morning audit, before the polish batch above.)

- **Roster reshape.** Dropped Goomgum + ENAI (hard delete, FKs respected); added LITH K, Sarabi, Borey; promoted Katrin Losa to verified. Nuked the duplicate `moh` / `moh-2` accounts cleanly (artists + profiles + auth.users in the right order).
- **Per-artist Linktree at `/a/<handle>`.** New `a.html` page renders a polished link-in-bio surface for any artist using their `handle`. Apache rewrite at `/a/<handle>` forwards to `a.html?h=<handle>` for humans and to the `profile-share` edge function (with full unfurl meta) for crawlers (UA match: WhatsApp/facebookexternalhit/Twitterbot/Slackbot/TelegramBot/Discordbot/LinkedInBot/Embedly/Pinterest/vkShare/redditbot/Skype).
- **`/link.html` link-in-bio.** Brand-side Linktree at `rosterplus.io/link` with 4 primary CTAs (book, join roster, browse directory, iOS) + social row + featured-artist card.
- **Homepage 2026-05-12 audit revisions.** Stats strip, social-proof venue strip, pricing card restructure (founding-50 anchored at "first 50 free, then 5% commission"), CTA hierarchy fixed, JSON-LD `MusicGroup` + `FAQPage` added, 6-question Gulf-specific FAQ section.
- **Per-artist share previews.** WhatsApp / Facebook / Twitter / Slack now unfurl with the artist's name, photo, genre, base fee — served by the existing `profile-share` edge function, gated by the htaccess UA match above. Fixed an Apache backref bug where `%2` was used to extract the UUID (only the LAST `RewriteCond` exposes groups) by passing `%{QUERY_STRING}` through verbatim.
- **App icon set regenerated.** New minimal "R+" + ROSTR+ wordmark with the green corner accent; all 9 PNG sizes + maskable + SVG written by `ios/scripts/generate-app-icon.swift`.

## What landed in the 2026-04-29 batch

- **Reviews feature dropped from both clients** per product call. Server-side preserved (table, RPCs, edge function intact, cron paused) so the decision is reversible. iOS: deleted `Features/Review/`, deleted `Stores/ReviewStore.swift`, removed `Route.review`, removed BookingsView review-prompt banner, dropped the `.review` mock notification, dropped `Route.parse("/reviews/<id>")`. Web: removed `renderReviewCard` + `submitReview` from `booking-detail.html`, removed reviews list + rating badge + JSON-LD `aggregateRating` from `profile.html`, dropped `DB.createReview` / `DB.reviewStatsForUser` / `DB.reviewsForUser` from `app.js`, softened `index.html` "07 / TRUST" copy, removed "Post-event review prompts" from `status.html`. Tests still green: **108** (was 109 — one ReviewStore test deleted with the store). The `send-review-prompts` cron job is `cron.alter_job(active := false)`. The `.review` notification kind stays in the iOS `RowKind` enum + web timeline label map so any pre-existing rows still render gracefully (no-op tap on iOS, label only on web).
- **Supabase — REVOKE EXECUTE on 10 trigger-class SECURITY DEFINER functions.** Migration `revoke_execute_on_trigger_class_functions` blocks REST callers from invoking `audit_artist_change`, `audit_artist_insert`, `handle_new_user`, `log_booking_status_change`, `notify_booking_event`, `notify_contract_event`, `notify_message_event`, `notify_payment_event`, `notify_push_on_notification`, `rls_auto_enable`. Triggers continue to fire (Postgres bypasses EXECUTE on trigger invocations). Advisor: 35 → 25 anon-executable warnings.

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
- **🔴 iOS sign-out cross-user leak fixed.** AppRoot now resets `availabilityCheck`, `analytics`, and `push` stores on `signedOut` (previously only 10 of 13 stores). `PushStore.clearToken(for:)` is called with the previous user's UUID so the device-tokens row is removed — user B signing in on the same device no longer inherits user A's APNs registration. Added `reset()` methods to PushStore + AvailabilityCheckStore + AnalyticsStore. **109 tests still passing.**
- **🔴 Apple App Site Association file added.** `web/.well-known/apple-app-site-association` ships with the right components map (bookings, threads, contracts, invoices, reviews, artists, epks, notifications), webcredentials, and `Content-Type: application/json` enforced via `netlify.toml`. AppID `CHSAVJ5X6U.io.rosterplus.app` is wired in. Universal links unblock as soon as Netlify serves the file from the deploy.
- **🟠 CSP `worker-src 'self'` added** to the Netlify CSP header — strict CSP validators stop flagging the SW registration.
- **🟠 `shared/types/supabase.ts` regenerated** from the live schema (2026-04-28).
- **STATUS.md correction:** `UIBackgroundModes = remote-notification` was already set in `ios/Config/Shared.xcconfig` before this audit. Previous STATUS listed it as pending — that was wrong.

## Outstanding follow-ups (not P0)

From the 2026-04-25 + 2026-04-27 + 2026-04-28 audits, re-counted 2026-05-12:

**Operator-only (cannot be done from a coding session):**
- **Supabase leaked-password protection (HaveIBeenPwned) is disabled.** Dashboard toggle at Auth → Settings → Password Strength. Required for launch given the platform handles money.
- **TestFlight build 5.** Blocked on Apple Distribution cert + provisioning profile. Build 4 is live; iOS code is at `c787d5f`.
- **App Store submission.** Metadata draft at `workspace/docs/APP_STORE_METADATA.md`; needs screenshots + demo account + reviewer notes.
- **Drop in two missing roster photos.** `assets/images/artists/anturage.jpg` and `assets/images/artists/eva-kim.jpg` (the other 9 are in). Falls through to initials until provided.
- **Confirm `/link.html` social handles** are real (IG/LinkedIn/X). Currently using ROSTR+ corporate handles; the link UI is one find-and-replace away.

**Code-side, low priority:**
- **Supabase advisor — 25 SECURITY DEFINER functions are anon-executable** (down from 35 on 2026-04-29). The remaining 25 are all client-callable by design (rate limiters, admin RPCs that internally check `is_admin()`, public helpers like `check_availability` / `create_review` / `cron_health_*`).
- **Web inline-style cleanup** — re-counted 2026-05-12: `admin.html` 148, `dashboard.html` 20, `artist-dashboard.html` ~30, `settings.html` / `messages.html` / `profile.html` / `payments.html` similar. Was 222/28 in the audit — prior batches chipped at it without updating STATUS. Extract to `system.css` utility classes when touching these files.
- **Web aria-label sweep** — re-verified 2026-05-12: the contracts.html "4/15 unlabeled" and dashboard.html "2/5 unlabeled" findings are **false positives**. Every flagged button has a visible text label ("Close", "Cancel", "Generate Contract", "All", "Signed", etc.) which screen readers read by default. `aria-label` would actually fight the visible text. Treat as resolved.
- **Localization sweep** — foundation is in place (24 keys + EN/AR + type-safe accessors). 123 literal `Text("...")` strings remain across iOS views. Incremental sweep, no big-bang.
- **Supabase advisor**: `admin_rate_counter` has RLS enabled but no policies. Documented as intentional via `COMMENT ON TABLE`; advisor still flags as INFO.

---

## How this file gets updated

Hand-maintained. Update at:

- After a meaningful release (multiple PRs landing in a batch).
- After resolving an incident.
- After a quarterly audit pass.

The shared repo's `RPC_CONTRACT.md` is the source of truth for which client calls what — this file is the higher-level snapshot pointing back to it.
