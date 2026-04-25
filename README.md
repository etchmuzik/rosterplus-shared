# rosterplus-shared

Cross-platform contract for the [ROSTR+](https://rosterplus.io)
booking platform. The two clients —
[rosterplusapp](https://github.com/etchmuzik/rosterplusapp) (web) and
[rosterplusapp-ios](https://github.com/etchmuzik/rosterplusapp-ios)
(iOS) — talk to the same Supabase project. This repo carries the
agreement they share, so they don't silently drift.

**Last sync with live schema: 2026-04-25.**

## What's in here

| File | Size | What it carries |
|---|---|---|
| [`types/supabase.ts`](./types/supabase.ts) | 1214 lines | Generated TypeScript types from the live schema — 17 tables, ~30 RPCs, full Row/Insert/Update + FK relationships. |
| [`RPC_CONTRACT.md`](./RPC_CONTRACT.md) | 174 lines | Every public RPC and edge function with its caller list per client, plus semantic notes the types can't carry. |
| [`SCHEMA_NOTES.md`](./SCHEMA_NOTES.md) | 153 lines | Soft-delete conventions, status enum values, realtime channels, RLS helpers, FK shapes worth memorizing. |
| [`scripts/regenerate-types.sh`](./scripts/regenerate-types.sh) | — | One-command refresh of `types/supabase.ts` from the live schema. |

## Why this exists

The 2026-04-25 audit found that iOS and web had **no overlapping
RPCs** — they hit the same project but used disjoint API surfaces.
That kind of drift happens silently when there's no single document
you have to update when you ship a schema change. This repo is that
document.

The repo is **not a build dependency**. Web is plain HTML+vanilla JS
with no bundler; iOS has hand-written Swift DTOs in `Stores/`. Neither
client *imports* anything from here today. It serves as a reference:
**before adding a new DB call, cross-check this repo first**.

## How to update

When the Supabase schema changes:

```bash
./scripts/regenerate-types.sh                  # refresh types/supabase.ts
$EDITOR RPC_CONTRACT.md                        # update caller lists if functions added/removed
$EDITOR SCHEMA_NOTES.md                        # update enum values / FK notes if relevant
git add . && git commit -m "chore: refresh types post-<change>"
git push
```

When a client adds or removes a call to a server-side function:

```bash
$EDITOR RPC_CONTRACT.md                        # update the iOS or Web bullet for that function
git add RPC_CONTRACT.md && git commit -m "docs: <function> now called by <client>"
git push
```

## Cadence

- **On every schema change**: regenerate types + update doc.
- **On every RPC client wiring change**: update `RPC_CONTRACT.md`.
- **Quarterly audit**: re-read `RPC_CONTRACT.md` top-to-bottom and
  compare against actual call-sites. Drift here is the canary for
  drift in production behavior.

## Project ID reference

- Production Supabase project: `vgjmfpryobsuboukbemr` ("roster new",
  eu-west-1).
- Live web: <https://rosterplus.io> (Hostinger auto-deploys from
  [`rosterplusapp`](https://github.com/etchmuzik/rosterplusapp)).
- iOS: ships via TestFlight from
  [`rosterplusapp-ios`](https://github.com/etchmuzik/rosterplusapp-ios).
