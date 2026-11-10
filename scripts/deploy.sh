#!/usr/bin/env bash
# Validates the given source paths against howto-npc with the project's Apex tests, then quick-deploys.
# The org cannot run RunLocalTests: four of Nonprofit Cloud's own classes have no tests and hold
# org-wide coverage at 42%. So deploys run the project's tests, which cover every class and trigger we ship.
# Usage: scripts/deploy.sh <path> [<path> ...]
set -euo pipefail
org=howto-npc
args=()
for p in "$@"; do args+=(--source-dir "$p"); done
tests=(--tests HowToDataModelTest)
[ -f force-app/main/default/classes/VotingBoardServiceTest.cls ] && tests+=(--tests VotingBoardServiceTest)
out=$(sf project deploy validate --target-org "$org" "${args[@]}" --test-level RunSpecifiedTests "${tests[@]}" --wait 40 --json 2>/dev/null || true)
id=$(jq -r '.result.id // empty' <<<"$out")
if [ "$(jq -r '.result.status // empty' <<<"$out")" != "Succeeded" ]; then
  jq -r '.message // empty' <<<"$out" | tr ',' '\n'
  jq -c '.result.details.componentFailures[]? | {fullName, problem}' <<<"$out"
  echo "VALIDATION FAILED ${id}"; exit 1
fi
echo "validated $id: $(jq -r '.result.numberTestsTotal' <<<"$out") tests passed"
sf project deploy quick --job-id "$id" --target-org "$org" --wait 30 --json 2>/dev/null | jq -r '"deployed " + .result.id + ": " + .result.status + ", " + (.result.numberComponentsDeployed|tostring) + " components"'
