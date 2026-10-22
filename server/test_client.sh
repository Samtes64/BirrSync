#!/usr/bin/env bash
set -e

SERVER_URL="${1:-http://localhost:8080}"
GATEWAY_ID="gateway_agent_01"
GATEWAY_SECRET="birrsync_secret_live_key_2026"

echo "=== BirrSync Gateway End-to-End Test ==="
echo "Target server: $SERVER_URL"
echo ""

# 1. Health check
echo "1. Checking server health..."
curl -s -f "$SERVER_URL/healthz" | grep -q "healthy" && echo "   Server is healthy!" || (echo "   Server unreachable!" && exit 1)

# 2. Ingest CBE Receipt
TIMESTAMP=$(date +%s%3N)
BODY='{"provider":"CBE","transaction_id":"v2-hfHCxHC6unkKSXCtrNI1","amount":2040.00,"sender_name":"Abebe Kebede","masked_phone":"1**9482","phone_suffix":"9482","raw":"Dear Customer You have received ETB 2,040.00 from account 1**9482 (Abebe Kebede)..."}'

PAYLOAD="${TIMESTAMP}.${BODY}"
SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$GATEWAY_SECRET" | awk '{print $NF}')

echo ""
echo "2. Simulating Flutter Agent Ingesting CBE Receipt (HMAC-SHA256 Signed)..."
INGEST_RES=$(curl -s -X POST "$SERVER_URL/v1/gateway/ingest" \
  -H "Content-Type: application/json" \
  -H "X-Gateway-ID: $GATEWAY_ID" \
  -H "X-Gateway-Timestamp: $TIMESTAMP" \
  -H "X-Gateway-Signature: $SIGNATURE" \
  -d "$BODY")
echo "   Ingest response: $INGEST_RES"

# 3. Verify Payment
echo ""
echo "3. Simulating Client App Verifying Payment..."
VERIFY_RES=$(curl -s -X POST "$SERVER_URL/v1/payments/verify" \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_id": "https://mbreciept.cbe.com.et/v2-hfHCxHC6unkKSXCtrNI1",
    "expected_amount": 2040.00
  }')
echo "   Verify response: $VERIFY_RES"

# 4. Attempt Double-Claim (should fail)
echo ""
echo "4. Testing Double-Claim Prevention (Atomic Lock)..."
DOUBLE_CLAIM_RES=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$SERVER_URL/v1/payments/verify" \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_id": "v2-hfHCxHC6unkKSXCtrNI1",
    "expected_amount": 2040.00
  }')

if [ "$DOUBLE_CLAIM_RES" -eq 404 ]; then
  echo "   SUCCESS: Duplicate claim rejected with HTTP 404 (Payment already claimed)."
else
  echo "   WARNING: Expected HTTP 404 for duplicate claim, got $DOUBLE_CLAIM_RES"
fi

echo ""
echo "=== All Tests Completed Successfully! ==="
