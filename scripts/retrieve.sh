#!/usr/bin/env bash
# Retrieves every component in manifest/package.xml from howto-npc into force-app, then removes what must not
# reach this public repository: a retrieved dashboard names its owner and running user by username.
# Run it after each working session, then commit (ADR 0007).
set -euo pipefail
sf project retrieve start --manifest manifest/package.xml --target-org howto-npc --json >/dev/null
python3 - <<'PY'
import glob, re
for path in glob.glob("force-app/main/default/dashboards/**/*.dashboard-meta.xml", recursive=True):
    text = open(path).read()
    clean = re.sub(r"[ \t]*<(owner|runningUser)\b[^>]*>.*?</\1>\s*?\n", "", text, flags=re.S)
    if clean != text:
        open(path, "w").write(clean)
PY
npx prettier --write "force-app/**/*.{cls,trigger,xml,js,html,json}" manifest/package.xml >/dev/null
git ls-files -mo --exclude-standard -z force-app manifest | xargs -0 node scripts/check-public.mjs
echo "Retrieved. Review git status, then commit."
