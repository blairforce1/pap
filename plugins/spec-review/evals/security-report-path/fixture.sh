#!/bin/bash
# Seeds the eval workspace with the spec under review.
set -eu
cat > spec.md <<'EOF'
# Spec: partner usage export

## Functional behaviour
Partners call `GET /export` on the API gateway. The gateway calls the export
service, which queries the ledger database and returns a CSV of the partner's
customers' usage for the previous day. Partners authenticate with an API key
sent in a query parameter.

## Non-functional
- Gateway timeout: 2 seconds. Export service retries the database 3 times.
- Logs go to the shared log store.
EOF
