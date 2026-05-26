#!/usr/bin/env bash
set -euo pipefail
##Author Bogdan Mosneagu Bogdan-Constantin.Mosneagu@kapsch.net January 2026
#Script to be run after the segment_discovery script. 
# Export the spreadsheet to csv and then run dos2unix tolling.csv
#Create a user and asssign it an API 
#

# ---------------- CONFIG ----------------
ZABBIX_URL="https://IP/api_jsonrpc.php"
API_TOKEN=""
HOST_GROUP_ID=""
TEMPLATE_NAME="G3 RSS"
CSV_FILE="./tolling.csv"
DEVICES=(ALC PFM VDC VR TSMC)

# ---------------- FUNCTION ----------------
api() {
  curl -sk -X POST "$ZABBIX_URL" \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer $API_TOKEN" \
       -d "$1"
}

echo ">>> Starting Zabbix host creation"
echo "Using host group ID: $HOST_GROUP_ID"
echo "Reading CSV: $CSV_FILE"

# ---------------- GET TEMPLATE ID ----------------
TEMPLATE_ID=$(api "{
  \"jsonrpc\": \"2.0\",
  \"method\": \"template.get\",
  \"params\": { \"filter\": { \"host\": [\"$TEMPLATE_NAME\"] } },
  \"id\": 1
}" | jq -r '.result[0].templateid // empty')

if [[ -z "$TEMPLATE_ID" ]]; then
  echo "❌ Template '$TEMPLATE_NAME' not found!"
  exit 1
fi
echo "Using template ID: $TEMPLATE_ID"
# ---------------- PROCESS CSV ----------------
tail -n +2 "$CSV_FILE" | while IFS=',' read -r DOMAIN POINT SEGMENT INSTANCE SOURCE; do
  DOMAIN=${DOMAIN//[[:space:]]/}
  POINT=${POINT//[[:space:]]/}
  SEGMENT=${SEGMENT//[[:space:]]/}
  INSTANCE=${INSTANCE//[[:space:]]/}
  SOURCE=${SOURCE//[[:space:]]/}

  [[ -z "$SOURCE" ]] && continue
  echo "Processing source: $SOURCE"

  for DEVICE in "${DEVICES[@]}"; do
    HOSTNAME="${SOURCE}-${DEVICE}"
    echo "  → Processing host: $HOSTNAME"

    # Check if host exists
    API_GET=$(api "{
      \"jsonrpc\":\"2.0\",
      \"method\":\"host.get\",
      \"params\":{\"filter\":{\"host\":[\"$HOSTNAME\"]}},
      \"id\":1
    }")
    EXISTS=$(echo "$API_GET" | jq -r '.result | length // 0')

    if [[ "$EXISTS" != "0" ]]; then
      echo "    ⚠ Host already exists"
      continue
    fi
# Create host with template
    API_CREATE=$(api "{
      \"jsonrpc\":\"2.0\",
      \"method\":\"host.create\",
      \"params\":{
        \"host\":\"$HOSTNAME\",
        \"name\":\"$HOSTNAME\",
        \"groups\":[{\"groupid\":\"$HOST_GROUP_ID\"}],
        \"templates\":[{\"templateid\":\"$TEMPLATE_ID\"}],
        \"interfaces\":[{
          \"type\":1,
          \"main\":1,
          \"useip\":1,
          \"ip\":\"127.0.0.1\",
          \"dns\":\"\",
          \"port\":\"10050\"
        }],
        \"macros\":[
          {\"macro\":\"{\$G3.DEVICE}\",\"value\":\"$DEVICE\"},
          {\"macro\":\"{\$G3.TOLLING.DOMAIN}\",\"value\":\"$DOMAIN\"},
          {\"macro\":\"{\$G3.TOLLING.POINT}\",\"value\":\"$POINT\"},
          {\"macro\":\"{\$G3.TOLLING.SEGMENT}\",\"value\":\"$SEGMENT\"},
          {\"macro\":\"{\$G3.TOLLING.INSTANCE}\",\"value\":\"$INSTANCE\"}
        ]
      },
      \"id\":1
    }")

    if echo "$API_CREATE" | jq -e '.result.hostids[0]' >/dev/null 2>&1; then
      echo "    ✓ Created and linked to template '$TEMPLATE_NAME'"
    else
      echo "    ⚠ Failed"
      echo "      API response: $API_CREATE"
    fi
  done
done
echo ">>> All hosts processed"