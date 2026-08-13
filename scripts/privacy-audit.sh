#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

failures=0

check_tracked_pattern() {
  local label="$1"
  local pattern="$2"
  if git grep -I -P -q "$pattern" -- ':!desktop/package-lock.json' ':!scripts/privacy-audit.sh'; then
    echo "Privacy audit failed: $label found in tracked content." >&2
    failures=1
  fi
}

check_tracked_pattern "personal home path" '(/Users/(?!example(?:[-_][^/]+)?(?:/|$))|/home/(?!example(?:[-_][^/]+)?(?:/|$))|C:\\Users\\(?!example(?:[-_][^\\]+)?(?:\\|$)))'
check_tracked_pattern "private IPv4 address" '(192\.168\.[0-9]{1,3}\.[0-9]{1,3}|10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})'
check_tracked_pattern "private network hostname" 'tail[0-9]+\.ts\.net'
check_tracked_pattern "private key material" 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'
check_tracked_pattern "Bitcoin address" 'bc1[ac-hj-np-z02-9]{20,}'

unexpected_emails="$({
  git grep -I -h -P -o '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' -- ':!desktop/package-lock.json' ':!scripts/privacy-audit.sh' || true
} | sort -u | rg -v '^(security@vortexradar\.com|[^@]+@example\.com)$' || true)"
if [[ -n "$unexpected_emails" ]]; then
  echo "Privacy audit failed: an unapproved email address is present in tracked content." >&2
  failures=1
fi

author_email="$(git log -1 --format='%ae')"
if [[ ! "$author_email" =~ @(users\.)?noreply\.github\.com$ ]]; then
  echo "Privacy audit failed: the current commit author must use a GitHub no-reply address." >&2
  failures=1
fi

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi

echo "Privacy audit passed."
