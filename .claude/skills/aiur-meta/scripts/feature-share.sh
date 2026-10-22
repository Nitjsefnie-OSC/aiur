#!/usr/bin/env bash
# Share of default-branch merges that are feature work, over a window.
# Usage: feature-share.sh [hours]   (default 24; run from the repository checkout)
#        feature-share.sh --self-test
# Each merged PR is classified by its closing ticket's labels and title:
# build-lane:/feature:/build-order = feature; flake/test/quarantine/CI words = test_ci; the rest = other.
set -u

classify() {
  case "$1" in
    *build-lane:*|*feature:*|*build-order*) echo feature ;;
    *) if printf '%s' "$1" | grep -qiE 'flak|test|quarantin|(^|[^a-z])ci([^a-z]|$)|merge.group|soak|coverage'; then echo test_ci; else echo other; fi ;;
  esac
}

if [ "${1:-}" = --self-test ]; then
  [ "$(classify 'build-lane:home,agent:done Build home: band')" = feature ] &&
  [ "$(classify 'flake,agent:todo Flake: PresenterTest')" = test_ci ] &&
  [ "$(classify 'agent:todo Pin CI runners')" = test_ci ] &&
  [ "$(classify 'agent:todo Daemon CPU from DeliveryLog')" = other ] &&
  echo "feature-share self-test: ok" && exit 0
  echo "feature-share self-test: FAILED" >&2; exit 1
fi

H=${1:-24}
G() { env -u GITHUB_TOKEN -u GH_TOKEN gh "$@"; }
repo=$(G repo view --json nameWithOwner -q .nameWithOwner) || exit 1
base=$(G repo view --json defaultBranchRef -q .defaultBranchRef.name) || exit 1
git fetch -q origin "$base" || exit 1
f=0 t=0 o=0
for p in $(git log --since="$H hours ago" --format='%s' "origin/$base" | grep -oE '\(#[0-9]+\)$' | tr -d '(#)'); do
  n=$(G pr view "$p" -R "$repo" --json body,headRefName -q '(.body|capture("(?i)(closes|fixes|resolves) #(?<n>[0-9]+)").n) // (.headRefName|capture("^aiur/(?<n>[0-9]+)").n) // ""' 2>/dev/null)
  line=""
  [ -n "$n" ] && line=$(G issue view "$n" -R "$repo" --json labels,title -q '([.labels[].name]|join(",")) + " " + .title' 2>/dev/null)
  case $(classify "$line") in feature) f=$((f+1)) ;; test_ci) t=$((t+1)) ;; *) o=$((o+1)) ;; esac
done
total=$((f+t+o))
# No merges is "not captured", never 0%.
[ "$total" -eq 0 ] && { echo "window=${H}h merges=0 feature_share=not_captured"; exit 0; }
echo "window=${H}h merges=$total feature=$f test_ci=$t other=$o feature_share=$((100*f/total))%"
