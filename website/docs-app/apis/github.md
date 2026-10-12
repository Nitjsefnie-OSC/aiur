# GitHub

Aiur reads GitHub to discover work, follow tickets, and return completed changes for review. This API reference is split by topic:

- [Polling, repository setup, and cadence](/apis/github-polling)
- [API budgets and credential pooling](/apis/github-budgets)
- [Per-caller cost accounting](/apis/github-costs)
- [Webhooks and resource reconciliation](/apis/github-webhooks)
- [Credentials, trust, and tunnel security](/apis/github-auth)
- [Shared agent reads](/apis/github-agent-cache)

## Legacy topic links

The original topic fragments remain available below for links that predate this split.

### CI failure evidence

See [CI failure evidence](/apis/ci-failure-evidence).

### Poll cadence

Polling intervals and per-class cadence are documented in [GitHub polling](/apis/github-polling#poll-cadence).

### API budgets

Budget meters, attribution, and pooling are documented in [GitHub API budgets](/apis/github-budgets).

### Reading these numbers without fooling yourself

Interpretation guidance lives in [GitHub API budgets](/apis/github-budgets#reading-these-numbers-without-fooling-yourself).

### Shared agent reads

The cache contract lives in [Shared agent GitHub reads](/apis/github-agent-cache).

### Optional webhook

Webhook setup and delivery state lives in [GitHub webhooks](/apis/github-webhooks#optional-webhook).

### Cloudflare tunnel boundary

Tunnel security lives in [GitHub credentials and security](/apis/github-auth#cloudflare-tunnel-boundary).

### Who Aiur trusts

Trust rules live in [GitHub credentials and security](/apis/github-auth#who-aiur-trusts).

### GitHub App authentication

App setup lives in [GitHub credentials and security](/apis/github-auth#github-app-authentication).

### Changes Aiur makes itself

Write-path details live in [Per-caller costs](/apis/github-costs).

### Comments arriving twice

Delivery reconciliation lives in [GitHub webhooks](/apis/github-webhooks#comments-arriving-twice).

### One record for one resource

The shared resource record lives in [GitHub webhooks](/apis/github-webhooks#one-record-for-one-resource).

### What the agent guard governs

The agent credential boundary lives in [GitHub credentials and security](/apis/github-auth#what-the-agent-guard-governs).

### Operator PR merge command

See the [CLI reference](/reference/cli#pr-merge).
