#!/usr/bin/env bash
# regenerate-types.sh — refresh types/supabase.ts from the live schema.
#
# Preferred path: Supabase CLI (no network round-trip through an MCP).
# Fallback: emit instructions for an MCP-based agent regen.

set -euo pipefail

PROJECT_ID="vgjmfpryobsuboukbemr"
OUT="$(cd "$(dirname "$0")/.." && pwd)/types/supabase.ts"

if command -v supabase >/dev/null 2>&1; then
  echo "Regenerating types via Supabase CLI..."
  supabase gen types typescript \
    --project-id "$PROJECT_ID" \
    --schema public > "$OUT"
  echo "Wrote $OUT"
  echo "Diff:"
  git diff --stat "$OUT" || true
  exit 0
fi

cat <<'EOF'
Supabase CLI not installed.

Install it:
  brew install supabase/tap/supabase

Then login:
  supabase login

Then run this script again.

Alternative path — ask Claude (or any agent with Supabase MCP access)
to run:

  generate_typescript_types(project_id="vgjmfpryobsuboukbemr")

and paste the result into types/supabase.ts.
EOF
exit 1
