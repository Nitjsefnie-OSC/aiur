# Spliced into github_push_guard.sh at its `@aiur-merge-queue-push-guard@`
# marker by Aiur.AgentGitHubGuard.GitScript; not a standalone script.
#
# A push to a pull request in the merge queue removes it from the queue, and
# the queue already tests the merge, so a base-refresh push only costs the
# runner pool (#4200). Agent workspaces only: the Executor keeps full push
# authority. A lookup that cannot answer lets the push through.
queue_install=false
case "$(dirname "$0")" in */.aiur-runtime/bin) queue_install=true ;; esac

if [ "$push_command" = true ] && [ "$queue_install" = true ] && [ -x "$(dirname "$0")/gh" ]; then
  queue_branch=$(git_in_context symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  queue_slug=${push_url#https://github.com/}
  queue_slug=${queue_slug%.git}

  queue_refspec=
  queue_hits_branch=false
  after_push=false

  for arg in "$@"; do
    if [ "$after_push" = false ]; then
      [ "$arg" = push ] && after_push=true
      continue
    fi
    case "$arg" in
      -*) continue ;;
    esac
    [ "$arg" = "$push_target" ] && continue
    queue_refspec=$arg
    case "${arg#+}" in
      HEAD | "$queue_branch" | *:"$queue_branch" | *:refs/heads/"$queue_branch") queue_hits_branch=true ;;
    esac
  done
  # A push with no refspec pushes the current branch.
  [ -n "$queue_refspec" ] || queue_hits_branch=true

  # Once the ticket is handed off, no worker wake may move the PR head while
  # the reviewer is examining it. Read the live tracker state at push time;
  # rework is the explicit exception after changes were requested. The leaf
  # workspace directory is the tracker issue number (or `pr-<number>` for a
  # watched PR workspace).
  ticket_leaf=${AIUR_AGENT_WORKSPACE##*/}
  ticket_number=${ticket_leaf#pr-}
  ticket_number=${ticket_number##*-}
  case "$ticket_number" in *[!0-9]* | '') ticket_number= ;; esac
  if [ -n "$queue_branch" ] && [ "$queue_hits_branch" = true ] && [ "$queue_slug" != "$push_url" ] &&
    [ -n "$ticket_number" ]; then
    ticket_state=$("$(dirname "$0")/gh" api "repos/$queue_slug/issues/$ticket_number" --jq '[.labels[].name] | join(" ")' 2>/dev/null || true)
    case " $ticket_state " in
      *" agent:human-review "*|*" agent:ci-wait "*)
        printf '%s\n' "aiur: refusing git push: ticket #$ticket_number is handed off for review or CI" >&2
        printf '%s\n' 'aiur: wait for the review verdict; pushes are allowed again after the ticket enters agent:rework' >&2
        exit 64
        ;;
    esac
  fi

  if [ -n "$queue_branch" ] && [ "$queue_hits_branch" = true ] && [ "$queue_slug" != "$push_url" ]; then
    queue_state=$("$(dirname "$0")/gh" api graphql \
      -f query='query($o:String!,$r:String!,$b:String!){repository(owner:$o,name:$r){pullRequests(headRefName:$b,states:OPEN,first:1){nodes{isInMergeQueue mergeable reviewDecision}}}}' \
      -f o="${queue_slug%%/*}" -f r="${queue_slug#*/}" -f b="$queue_branch" \
      --jq '.data.repository.pullRequests.nodes[0] | "\(.isInMergeQueue) \(.mergeable) \(.reviewDecision)"' 2>/dev/null || true)
    case "$queue_state" in
      'true CONFLICTING '* | 'true '*' CHANGES_REQUESTED') ;;
      'true '*)
        printf '%s\n' "aiur: refusing git push: the pull request for $queue_branch is in the merge queue and a push removes it" >&2
        printf '%s\n' 'aiur: the queue tests the merge itself; push only when GitHub reports the PR CONFLICTING or changes are requested' >&2
        exit 64
        ;;
    esac
  fi
fi
