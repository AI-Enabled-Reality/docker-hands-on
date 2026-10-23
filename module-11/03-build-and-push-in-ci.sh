#!/usr/bin/env bash
# Lesson 11.3, Build and push in CI: the practical as a shell session.
# It runs .github/workflows/release.yml in your copy of this repository on GitHub, with the GitHub CLI
# (gh auth login, with the workflow scope), and publishes ghcr.io/<you>/brightlane-pricing.
#   LAB_GITHUB_REPO=<you>/docker-hands-on bash module-11/03-build-and-push-in-ci.sh
# The break pushes a branch, m11l03-no-packages-permission, and deletes it at the end.
set -u
step() { printf '\n=== %s\n' "$*"; }
REPO=${LAB_GITHUB_REPO:?set LAB_GITHUB_REPO to your copy of the repository, such as you/docker-hands-on}
BREAK=m11l03-no-packages-permission
# Start the workflow on a branch, wait until it ends, print the run's id.
run_and_wait() {
  gh workflow run release.yml --repo "$REPO" --ref "$1" > /dev/null
  sleep 8
  local id
  id=$(gh run list --repo "$REPO" --workflow release.yml --branch "$1" --limit 1 --json databaseId --jq '.[0].databaseId')
  gh run watch "$id" --repo "$REPO" --interval 15 > /dev/null 2>&1
  echo "$id"
}
# The run's result, and each job's duration.
summary() {
  gh run view "$1" --repo "$REPO" --json conclusion,jobs \
    --jq '"run: \(.conclusion)", (.jobs[] | "  \(.name): \(.conclusion) in \((.completedAt | fromdate) - (.startedAt | fromdate)) s")'
}
# Lines of the run's log that match a pattern, without the job, step and timestamp columns.
log_lines() {
  gh run view "$1" --repo "$REPO" "${3:---log}" | grep -E "$2" | cut -f3 | cut -c30- \
    | perl -pe 's/(\e|\^\[)\[[0-9;]*m//g' | grep -v "^docker "
}
git push -q origin --delete $BREAK > /dev/null 2>&1

step "1. Run the release workflow on main"
id=$(run_and_wait main)
summary "$id"
log_lines "$id" "passed in|\"version\"|health endpoint answered"
gh run view "$id" --repo "$REPO" --log | grep -o '"tag-names":\[[^]]*\]' | head -1
log_lines "$id" "What was published" | grep -E "^(linux|unknown)/"

step "Break it: the same workflow without packages: write"
git switch -q -c $BREAK
sed -i.bak '/^  packages: write$/d' .github/workflows/release.yml && rm .github/workflows/release.yml.bak
git commit -q -m "Lesson 11.3: the release workflow without packages: write" .github/workflows/release.yml
git push -q origin $BREAK 2> /dev/null
git switch -q main
id=$(run_and_wait $BREAK)
summary "$id"
log_lines "$id" "#[0-9]+ ERROR: failed to push" --log-failed | sort -u

step "Clean up"
git push -q origin --delete $BREAK 2> /dev/null && git branch -q -D $BREAK && echo "branch $BREAK deleted"
