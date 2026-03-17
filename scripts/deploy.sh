#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# SBA 641 & 888 LWC — Deploy Script
# Michigan SBDC at GVSU | Attain Partners
#
# Usage:
#   ./scripts/deploy.sh           # full deploy + run tests
#   ./scripts/deploy.sh --check   # validate only (no deploy)
#
# Prerequisites:
#   sf org login web --alias fullsb \
#     --instance-url https://michigansbdcatgrandvalleystateuniv--fullsb.sandbox.my.salesforce.com
# ─────────────────────────────────────────────────────────────────────────────
set -e

ALIAS="fullsb"
SOURCE="force-app"

echo "════════════════════════════════════════"
echo "  SBA 641 & 888 LWC Reporting Refactor"
echo "  Target org alias: $ALIAS"
echo "════════════════════════════════════════"

if [[ "$1" == "--check" ]]; then
    echo ">> Validate only (no deploy)..."
    sf project deploy validate \
        --source-dir $SOURCE \
        --target-org $ALIAS \
        --test-level RunLocalTests \
        --wait 20
    echo ">> Validation passed."
    exit 0
fi

echo ">> Deploying to $ALIAS..."
sf project deploy start \
    --source-dir $SOURCE \
    --target-org $ALIAS \
    --wait 20

echo ""
echo ">> Running Apex tests..."
sf apex run test \
    --target-org $ALIAS \
    --test-level RunLocalTests \
    --wait 20 \
    --result-format human

echo ""
echo "✅  Deploy complete."
echo ""
echo "Next steps:"
echo "  1. Add sba641ReportingWizard to SBDC Admin App (Lightning App Builder)"
echo "  2. Add sba888ReportingWizard to SBDC Admin App"
echo "  3. Run end-to-end UAT with real quarter data before deactivating legacy Flows"
